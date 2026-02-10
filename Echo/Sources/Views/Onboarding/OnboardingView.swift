import SwiftUI

/// First-run setup wizard: permissions -> model download -> hotkey test.
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep: OnboardingStep = .welcome
    var onComplete: (() -> Void)?

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case permissions
        case modelDownload
        case hotkeySetup
        case complete
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(currentStep.rawValue), total: Double(OnboardingStep.allCases.count - 1))
                .padding()

            // Content
            Group {
                switch currentStep {
                case .welcome:
                    WelcomeStepView()
                case .permissions:
                    PermissionsStepView()
                        .environmentObject(appState)
                case .modelDownload:
                    ModelDownloadStepView()
                        .environmentObject(appState)
                case .hotkeySetup:
                    HotkeySetupStepView()
                        .environmentObject(appState)
                case .complete:
                    CompleteStepView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

            // Navigation buttons
            HStack {
                if currentStep != .welcome {
                    Button("Back") {
                        withAnimation {
                            if let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                                currentStep = prev
                            }
                        }
                    }
                }
                Spacer()
                if currentStep == .complete {
                    Button("Finish") {
                        appState.completeOnboarding()
                        onComplete?()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Next") {
                        withAnimation {
                            if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                                currentStep = next
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Step Views

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Welcome to Echo")
                .font(.title)
            Text("A privacy-first voice-to-text assistant for macOS.\nAll processing happens locally on your device.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
}

struct PermissionsStepView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions Required")
                .font(.title2)

            Text("When running from the terminal, permissions are granted to your **terminal app** (e.g., Terminal, iTerm2, Ghostty). You may need to add it in System Settings.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            PermissionRow(
                name: "Microphone",
                description: "Required to capture your voice for transcription.",
                granted: appState.permissionService.microphoneGranted,
                requestAction: { appState.permissionService.requestMicrophonePermission() },
                settingsAction: { appState.permissionService.openMicrophoneSettings() }
            )

            PermissionRow(
                name: "Accessibility",
                description: "Required to insert text into other applications.",
                granted: appState.permissionService.accessibilityGranted,
                requestAction: { appState.permissionService.requestAccessibilityPermission() },
                settingsAction: { appState.permissionService.openAccessibilitySettings() }
            )

            Spacer()

            Button("Refresh Permission Status") {
                appState.permissionService.refreshStatus()
            }
        }
    }
}

struct PermissionRow: View {
    let name: String
    let description: String
    let granted: Bool
    let requestAction: () -> Void
    let settingsAction: () -> Void

    var body: some View {
        HStack {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(granted ? .green : .red)
                .font(.title3)

            VStack(alignment: .leading) {
                Text(name).font(.headline)
                Text(description).font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            if !granted {
                Button("Grant", action: requestAction)
                Button("Open Settings", action: settingsAction)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ModelDownloadStepView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Download a Model")
                .font(.title2)
            Text("Choose a speech recognition model. You can change this later in Settings.")
                .foregroundColor(.secondary)

            ForEach(ModelManifest.catalog) { manifest in
                HStack {
                    VStack(alignment: .leading) {
                        Text(manifest.displayName).font(.headline)
                        Text(manifest.languageScope == .english ? "English only — faster" : "100+ languages")
                            .font(.caption).foregroundColor(.secondary)
                        Text("~\(manifest.fileSizeBytes / 1_000_000) MB")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    if appState.modelManager.isModelDownloaded(manifest.id) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Button(role: .destructive) {
                                try? appState.modelManager.deleteModel(manifest.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                    } else if appState.modelManager.downloadingModelID == manifest.id {
                        VStack(spacing: 2) {
                            ProgressView(value: appState.modelManager.downloadProgress)
                                .frame(width: 100)
                            Text("\(Int(appState.modelManager.downloadProgress * 100))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button("Download") {
                            appState.settingsStore.selectedModelID = manifest.id
                            Task {
                                try? await appState.modelManager.downloadModel(manifest)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if let error = appState.modelManager.downloadError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

struct HotkeySetupStepView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Text("Trigger Setup")
                .font(.title2)

            Image(systemName: "computermouse.fill")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)

            Text("Recording is triggered by:")
            Text(appState.settingsStore.hotkeyCombo.displayString)
                .font(.title)
                .bold()
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))

            Picker("Recording Mode", selection: Binding(
                get: { appState.settingsStore.recordMode },
                set: {
                    appState.settingsStore.recordMode = $0
                    appState.settingsStore.save()
                }
            )) {
                Text("Hold to Record").tag(RecordMode.hold)
                Text("Toggle").tag(RecordMode.toggle)
            }
            .pickerStyle(.segmented)
            .frame(width: 300)

            Text("Hold mode: press and hold the middle mouse button while speaking.\nToggle mode: click once to start, click again to stop.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct CompleteStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("Setup Complete")
                .font(.title)
            Text("Echo is ready. Use your hotkey to start dictating in any app.\nThe menu bar icon shows your current status.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
}
