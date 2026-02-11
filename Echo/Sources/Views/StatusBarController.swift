import AppKit
import Combine
import Sparkle

/// Manages the NSStatusItem (menu bar icon) and its menu.
@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private weak var delegate: AppDelegate?
    private let updaterController: SPUStandardUpdaterController
    private var cancellables = Set<AnyCancellable>()

    private var waveformTimer: Timer?
    private var wavePhase: CGFloat = 0
    private var displayLevel: CGFloat = 0

    init(statusItem: NSStatusItem, appState: AppState, delegate: AppDelegate, updaterController: SPUStandardUpdaterController) {
        self.statusItem = statusItem
        self.appState = appState
        self.delegate = delegate
        self.updaterController = updaterController
        super.init()
        setupStatusItem()
    }

    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Echo")
            button.image?.size = NSSize(width: 16, height: 16)
        }
        statusItem.menu = buildMenu()

        appState.$recordingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateStatusIcon()
                self.statusItem.menu = self.buildMenu()
            }
            .store(in: &cancellables)

        appState.$isModelLoaded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.statusItem.menu = self.buildMenu()
            }
            .store(in: &cancellables)

        appState.settingsStore.$showWaveformInMenuBar
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    self.startWaveformAnimation()
                } else {
                    self.stopWaveformAnimation()
                    self.updateStatusIcon()
                }
            }
            .store(in: &cancellables)
    }

    private func updateStatusIcon() {
        if appState.settingsStore.showWaveformInMenuBar {
            renderWaveformIcon()
            return
        }

        let symbolName: String
        switch appState.recordingState {
        case .idle:
            symbolName = "mic.fill"
        case .recording:
            symbolName = "mic.badge.plus"
        case .transcribing:
            symbolName = "waveform"
        case .inserting:
            symbolName = "text.cursor"
        case .error:
            symbolName = "exclamationmark.triangle.fill"
        }
        statusItem.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Echo")
        statusItem.button?.image?.size = NSSize(width: 16, height: 16)
    }

    private func startWaveformAnimation() {
        guard waveformTimer == nil else { return }
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickWaveform()
            }
        }
        renderWaveformIcon()
    }

    private func stopWaveformAnimation() {
        waveformTimer?.invalidate()
        waveformTimer = nil
        wavePhase = 0
        displayLevel = 0
    }

    private func tickWaveform() {
        wavePhase += 0.15

        let target = CGFloat(appState.audioLevel)
        if appState.recordingState == .recording {
            if target > displayLevel {
                displayLevel = displayLevel * 0.3 + target * 0.7
            } else {
                displayLevel = displayLevel * 0.85 + target * 0.15
            }
        } else {
            displayLevel = displayLevel * 0.7
        }

        renderWaveformIcon()
    }

    private func renderWaveformIcon() {
        let isRecording = appState.recordingState == .recording
        let isTranscribing = appState.recordingState == .transcribing || appState.recordingState == .inserting

        // When idle, use the standard mic icon
        if !isRecording && !isTranscribing {
            statusItem.button?.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Echo")
            statusItem.button?.image?.size = NSSize(width: 16, height: 16)
            return
        }

        let width: CGFloat = 22
        let height: CGFloat = 18

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let midY = rect.height / 2

            if isRecording {
                // Draw animated waveform when recording
                let effectiveAmplitude = max(self.displayLevel, 0.15)

                for wave in 0..<3 {
                    let baseAmp = rect.height * (0.4 - CGFloat(wave) * 0.08)
                    let amp = baseAmp * effectiveAmplitude
                    let frequency: CGFloat = 2.0 + CGFloat(wave) * 1.0
                    let wavePhaseOffset = self.wavePhase + CGFloat(wave) * 0.8
                    let opacity = 0.9 - Double(wave) * 0.25

                    let path = NSBezierPath()
                    for x in stride(from: 0, through: rect.width, by: 1) {
                        let normalizedX = x / rect.width
                        let envelope = sin(normalizedX * .pi)
                        let y = midY + sin(normalizedX * frequency * .pi * 2 + wavePhaseOffset) * amp * envelope
                        if x == 0 {
                            path.move(to: NSPoint(x: x, y: y))
                        } else {
                            path.line(to: NSPoint(x: x, y: y))
                        }
                    }

                    NSColor.systemBlue.withAlphaComponent(opacity).setStroke()
                    path.lineWidth = 1.5 - CGFloat(wave) * 0.3
                    path.stroke()
                }
            } else if isTranscribing {
                // Draw pulsing dots when transcribing/processing
                let dotSpacing: CGFloat = 6
                let baseRadius: CGFloat = 2.5
                let totalWidth = dotSpacing * 2
                let startX = (rect.width - totalWidth) / 2

                for i in 0..<3 {
                    let cycle = (self.wavePhase * 0.5 + CGFloat(i) * 0.7).truncatingRemainder(dividingBy: .pi * 2)
                    let scale = 0.7 + 0.5 * abs(sin(cycle))
                    let radius = baseRadius * scale

                    let x = startX + CGFloat(i) * dotSpacing
                    let dotRect = NSRect(
                        x: x - radius,
                        y: midY - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    let path = NSBezierPath(ovalIn: dotRect)
                    NSColor.systemBlue.withAlphaComponent(0.8).setFill()
                    path.fill()
                }
            }

            return true
        }

        image.isTemplate = false
        statusItem.button?.image = image
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Status
        let stateText: String
        switch appState.recordingState {
        case .idle: stateText = "Ready"
        case .recording: stateText = "Recording..."
        case .transcribing: stateText = "Transcribing..."
        case .inserting: stateText = "Inserting..."
        case .error(let err):
            switch err {
            case .permissionDenied(let type): stateText = "Permission needed: \(type.rawValue)"
            case .transcriptionFailed(let msg): stateText = "Error: \(msg)"
            case .insertionFailed(let msg): stateText = "Error: \(msg)"
            case .maxDurationReached: stateText = "Max duration reached"
            }
        }
        let statusMenuItem = NSMenuItem(title: stateText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        // Permission status
        if !appState.permissionService.microphoneGranted || !appState.permissionService.accessibilityGranted {
            let permItem = NSMenuItem(title: "⚠ Permissions needed — open Setup", action: #selector(openOnboarding), keyEquivalent: "")
            permItem.target = self
            menu.addItem(permItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Model info
        let modelText = appState.isModelLoaded
            ? "Model: \(appState.settingsStore.selectedModelID)"
            : "Model: not loaded"
        let modelItem = NSMenuItem(title: modelText, action: nil, keyEquivalent: "")
        modelItem.isEnabled = false
        menu.addItem(modelItem)
        menu.addItem(NSMenuItem.separator())

        // Setup wizard
        let setupItem = NSMenuItem(title: "Setup Wizard...", action: #selector(openOnboarding), keyEquivalent: "")
        setupItem.target = self
        menu.addItem(setupItem)

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        // Check for Updates
        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Echo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openSettings() {
        delegate?.showSettings()
    }

    @objc private func openOnboarding() {
        delegate?.showOnboarding()
    }
}
