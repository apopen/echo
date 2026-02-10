import SwiftUI

/// Main settings window with tabbed navigation.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .environmentObject(appState)

            ModelSettingsView()
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }
                .environmentObject(appState)

            ProcessingSettingsView()
                .tabItem {
                    Label("Processing", systemImage: "text.badge.checkmark")
                }
                .environmentObject(appState)

            AppRulesSettingsView()
                .tabItem {
                    Label("App Rules", systemImage: "app.badge")
                }
                .environmentObject(appState)

            PermissionsSettingsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
                .environmentObject(appState)
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Trigger") {
                HStack {
                    Text("Recording trigger:")
                    Text(appState.settingsStore.hotkeyCombo.displayString)
                        .bold()
                    Spacer()
                }
            }

            Section("Recording Mode") {
                Picker("Mode", selection: Binding(
                    get: { appState.settingsStore.recordMode },
                    set: { newMode in
                        appState.settingsStore.recordMode = newMode
                        appState.hotkeyService.updateMode(newMode)
                        appState.settingsStore.save()
                    }
                )) {
                    Text("Hold to Record").tag(RecordMode.hold)
                    Text("Toggle").tag(RecordMode.toggle)
                }
                .pickerStyle(.segmented)
            }

            Section("Recording") {
                HStack {
                    Text("Max duration:")
                    TextField("seconds", value: Binding(
                        get: { appState.settingsStore.maxRecordingDuration },
                        set: {
                            appState.settingsStore.maxRecordingDuration = $0
                            appState.settingsStore.save()
                        }
                    ), format: .number)
                    .frame(width: 80)
                    Text("seconds")
                }
            }

            Section("Privacy") {
                Toggle("Privacy Mode", isOn: Binding(
                    get: { appState.privacyMode },
                    set: { _ in appState.togglePrivacyMode() }
                ))
                Text("When enabled, clears history and blocks future writes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("System") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { appState.settingsStore.launchAtLogin },
                    set: {
                        appState.settingsStore.launchAtLogin = $0
                        appState.settingsStore.save()
                    }
                ))
            }
        }
        .padding()
    }
}

// MARK: - Model Settings

struct ModelSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Selected Model") {
                Picker("Model", selection: Binding(
                    get: { appState.settingsStore.selectedModelID },
                    set: {
                        appState.settingsStore.selectedModelID = $0
                        appState.settingsStore.save()
                    }
                )) {
                    ForEach(ModelManifest.catalog) { manifest in
                        Text(manifest.displayName).tag(manifest.id)
                    }
                }
            }

            Section("Available Models") {
                ForEach(appState.modelManager.availableModels(), id: \.manifest.id) { entry in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(entry.manifest.displayName)
                                .font(.headline)
                            Text(entry.manifest.languageScope == .english ? "English only" : "Multilingual (100+ languages)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if entry.downloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else if appState.modelManager.isDownloading {
                            ProgressView(value: appState.modelManager.downloadProgress)
                                .frame(width: 80)
                        } else {
                            Button("Download") {
                                Task {
                                    try? await appState.modelManager.downloadModel(entry.manifest)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }
}

// MARK: - Processing Settings

struct ProcessingSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Text Processing") {
                Toggle("Remove filler words (um, uh, like...)", isOn: Binding(
                    get: { appState.settingsStore.processingSettings.fillerRemovalEnabled },
                    set: {
                        appState.settingsStore.processingSettings.fillerRemovalEnabled = $0
                        appState.settingsStore.save()
                    }
                ))

                Toggle("Normalize numbers (one → 1)", isOn: Binding(
                    get: { appState.settingsStore.processingSettings.numberNormalizationEnabled },
                    set: {
                        appState.settingsStore.processingSettings.numberNormalizationEnabled = $0
                        appState.settingsStore.save()
                    }
                ))

                Toggle("Format punctuation and capitalization", isOn: Binding(
                    get: { appState.settingsStore.processingSettings.punctuationFormattingEnabled },
                    set: {
                        appState.settingsStore.processingSettings.punctuationFormattingEnabled = $0
                        appState.settingsStore.save()
                    }
                ))

                Toggle("Custom replacements", isOn: Binding(
                    get: { appState.settingsStore.processingSettings.customReplacementsEnabled },
                    set: {
                        appState.settingsStore.processingSettings.customReplacementsEnabled = $0
                        appState.settingsStore.save()
                    }
                ))
            }

            if appState.settingsStore.processingSettings.customReplacementsEnabled {
                Section("Replacement Rules") {
                    ReplacementRulesEditor(
                        rules: Binding(
                            get: { appState.settingsStore.processingSettings.customReplacements },
                            set: {
                                appState.settingsStore.processingSettings.customReplacements = $0
                                appState.settingsStore.save()
                            }
                        )
                    )
                }
            }
        }
        .padding()
    }
}

// MARK: - Replacement Rules Editor

struct ReplacementRulesEditor: View {
    @Binding var rules: [ReplacementRule]

    var body: some View {
        VStack(alignment: .leading) {
            ForEach($rules) { $rule in
                HStack {
                    TextField("Find", text: $rule.find)
                        .frame(width: 120)
                    Text("→")
                    TextField("Replace", text: $rule.replace)
                        .frame(width: 120)
                    Toggle("Case", isOn: $rule.caseSensitive)
                        .toggleStyle(.checkbox)
                    Button(role: .destructive) {
                        rules.removeAll { $0.id == rule.id }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Add Rule") {
                rules.append(ReplacementRule(find: "", replace: ""))
            }
        }
    }
}

// MARK: - App Rules Settings

struct AppRulesSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Per-App Rules") {
                if appState.settingsStore.appRules.isEmpty {
                    Text("No app-specific rules configured.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(appState.settingsStore.appRules) { rule in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(rule.displayName)
                                    .font(.headline)
                                Spacer()
                                Button(role: .destructive) {
                                    appState.settingsStore.appRules.removeAll { $0.id == rule.id }
                                    appState.settingsStore.save()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                            Text(rule.bundleID)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Toggle("Auto-send (Enter after insertion)", isOn: Binding(
                                get: { rule.autoSendEnabled },
                                set: { newValue in
                                    if let index = appState.settingsStore.appRules.firstIndex(where: { $0.id == rule.id }) {
                                        appState.settingsStore.appRules[index].autoSendEnabled = newValue
                                        appState.settingsStore.save()
                                    }
                                }
                            ))
                        }
                        .padding(.vertical, 4)
                    }
                }

                Button("Add Rule for Current App") {
                    if let frontApp = NSWorkspace.shared.frontmostApplication,
                       let bundleID = frontApp.bundleIdentifier {
                        let name = frontApp.localizedName ?? bundleID
                        let rule = AppRule(bundleID: bundleID, displayName: name)
                        appState.settingsStore.appRules.append(rule)
                        appState.settingsStore.save()
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Permissions Settings

struct PermissionsSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Permissions") {
                HStack {
                    Image(systemName: appState.permissionService.microphoneGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(appState.permissionService.microphoneGranted ? .green : .red)
                    Text("Microphone")
                    Spacer()
                    if !appState.permissionService.microphoneGranted {
                        Button("Grant") {
                            appState.permissionService.requestMicrophonePermission()
                        }
                        Button("Open Settings") {
                            appState.permissionService.openMicrophoneSettings()
                        }
                    }
                }

                HStack {
                    Image(systemName: appState.permissionService.accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(appState.permissionService.accessibilityGranted ? .green : .red)
                    Text("Accessibility")
                    Spacer()
                    if !appState.permissionService.accessibilityGranted {
                        Button("Grant") {
                            appState.permissionService.requestAccessibilityPermission()
                        }
                        Button("Open Settings") {
                            appState.permissionService.openAccessibilitySettings()
                        }
                    }
                }
            }

            Section {
                Button("Refresh Permissions") {
                    appState.permissionService.refreshStatus()
                }
            }
        }
        .padding()
    }
}
