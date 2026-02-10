import Foundation
import AppKit
import Combine
import os.log

/// Central application state coordinating all services and the dictation pipeline.
@MainActor
final class AppState: ObservableObject {
    private static let logger = Logger(subsystem: "com.echo", category: "AppState")

    // MARK: - Published State

    @Published var recordingState: RecordingState = .idle
    @Published var isModelLoaded: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var audioLevel: Float = 0.0

    // MARK: - Services

    let permissionService = PermissionService()
    let settingsStore = SettingsStore()
    let hotkeyService = HotkeyService()
    let recordingService = RecordingService()
    let transcriptionService = TranscriptionService()
    let insertionService = InsertionService()
    let processingPipeline = ProcessingPipeline()
    let modelManager = ModelManager()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func initialize() {
        settingsStore.load()
        hasCompletedOnboarding = settingsStore.hasCompletedOnboarding

        setupHotkeyBindings()
        setupAudioLevelMonitor()

        if hasCompletedOnboarding {
            loadSelectedModel()
        }
    }

    func shutdown() {
        hotkeyService.unregister()
        recordingService.stop()
    }

    func handleWake() {
        permissionService.refreshStatus()
    }

    func handleSleep() {
        if recordingState == .recording {
            cancelRecording()
        }
    }

    // MARK: - Dictation Pipeline

    func startRecording() {
        guard recordingState == .idle else {
            Self.logger.warning("Cannot start recording: state is \(String(describing: self.recordingState))")
            return
        }
        guard isModelLoaded else {
            Self.logger.warning("Cannot start recording: model not loaded")
            recordingState = .error(.transcriptionFailed("Model not loaded"))
            scheduleErrorReset()
            return
        }

        permissionService.refreshStatus()
        guard permissionService.microphoneGranted else {
            Self.logger.warning("Cannot start recording: microphone not granted")
            permissionService.requestMicrophonePermission()
            recordingState = .error(.permissionDenied(.microphone))
            scheduleErrorReset()
            return
        }

        Self.logger.info("Starting recording")
        recordingState = .recording
        recordingService.start(maxDuration: settingsStore.maxRecordingDuration) { [weak self] in
            Task { @MainActor in
                self?.handleMaxDurationReached()
            }
        }
    }

    func stopRecording() {
        guard recordingState == .recording else { return }
        let audioBuffer = recordingService.stop()
        guard let audioBuffer, !audioBuffer.isEmpty else {
            Self.logger.warning("Recording stopped but buffer was empty")
            recordingState = .idle
            return
        }
        Self.logger.info("Recording stopped, \(audioBuffer.count) samples captured")
        audioLevel = 0
        beginTranscription(audioBuffer)
    }

    func cancelRecording() {
        recordingService.stop()
        recordingState = .idle
    }

    // MARK: - Private

    private func handleMaxDurationReached() {
        guard recordingState == .recording else { return }
        let audioBuffer = recordingService.stop()
        guard let audioBuffer, !audioBuffer.isEmpty else {
            recordingState = .idle
            return
        }
        NotificationHelper.postMaxDurationReached()
        beginTranscription(audioBuffer)
    }

    private func beginTranscription(_ audioData: [Float]) {
        recordingState = .transcribing
        Self.logger.info("Beginning transcription of \(audioData.count) samples")

        Task {
            do {
                let rawText = try await transcriptionService.transcribe(
                    audioData,
                    language: settingsStore.selectedModelID.hasSuffix(".en") ? "en" : nil
                )

                Self.logger.info("Transcription result: '\(rawText)'")

                guard !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    Self.logger.info("Transcription was empty, returning to idle")
                    recordingState = .idle
                    return
                }

                let processedText = processingPipeline.process(
                    rawText,
                    settings: settingsStore.processingSettings,
                    appBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                )

                recordingState = .inserting
                await insertText(processedText)
            } catch {
                Self.logger.error("Transcription failed: \(error)")
                recordingState = .error(.transcriptionFailed(error.localizedDescription))
                scheduleErrorReset()
            }
        }
    }

    private func insertText(_ text: String) async {
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let autoSend = settingsStore.shouldAutoSend(forBundleID: bundleID)

        do {
            try await insertionService.insert(text, autoSend: autoSend)
            Self.logger.info("Text copied to clipboard: '\(text)'")
        } catch {
            Self.logger.error("Insertion failed: \(error)")
        }

        recordingState = .idle
    }

    private func setupAudioLevelMonitor() {
        recordingService.onAudioLevel = { [weak self] level in
            DispatchQueue.main.async {
                self?.audioLevel = level
            }
        }
    }

    private func scheduleErrorReset() {
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if case .error = recordingState {
                recordingState = .idle
            }
        }
    }

    private func setupHotkeyBindings() {
        hotkeyService.onKeyDown = { [weak self] in
            Task { @MainActor in
                self?.handleHotkeyDown()
            }
        }
        hotkeyService.onKeyUp = { [weak self] in
            Task { @MainActor in
                self?.handleHotkeyUp()
            }
        }

        hotkeyService.register(
            combo: settingsStore.hotkeyCombo,
            mode: settingsStore.recordMode
        )
    }

    private func handleHotkeyDown() {
        switch settingsStore.recordMode {
        case .hold:
            startRecording()
        case .toggle:
            if recordingState == .recording {
                stopRecording()
            } else if recordingState == .idle {
                startRecording()
            }
        }
    }

    private func handleHotkeyUp() {
        switch settingsStore.recordMode {
        case .hold:
            if recordingState == .recording {
                stopRecording()
            }
        case .toggle:
            break
        }
    }

    private func loadSelectedModel() {
        let modelID = settingsStore.selectedModelID
        let modelPath = modelManager.modelPath(for: modelID)

        guard modelManager.isModelDownloaded(modelID) else {
            Self.logger.warning("Cannot load model '\(modelID)' — file not found at \(modelPath)")
            isModelLoaded = false
            return
        }

        Self.logger.info("Loading model '\(modelID)' from \(modelPath)")

        Task {
            do {
                try await transcriptionService.loadModel(modelPath)
                isModelLoaded = true
                Self.logger.info("Model '\(modelID)' loaded successfully")
            } catch {
                Self.logger.error("Failed to load model '\(modelID)': \(error)")
                isModelLoaded = false
            }
        }
    }

    // MARK: - Public Actions

    func completeOnboarding() {
        hasCompletedOnboarding = true
        settingsStore.hasCompletedOnboarding = true
        settingsStore.save()
        Self.logger.info("Onboarding complete, selected model: \(self.settingsStore.selectedModelID)")
        loadSelectedModel()
    }
}
