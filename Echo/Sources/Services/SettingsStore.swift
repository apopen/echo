import Foundation
import os.log

/// Persists user settings via UserDefaults.
final class SettingsStore: ObservableObject {
    private static let logger = Logger(subsystem: "com.echo", category: "SettingsStore")
    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let hotkeyCombo = "hotkeyCombo"
        static let recordMode = "recordMode"
        static let selectedModelID = "selectedModelID"
        static let processingSettings = "processingSettings"

        static let launchAtLogin = "launchAtLogin"
        static let maxRecordingDuration = "maxRecordingDuration"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let appRules = "appRules"
        static let insertionMode = "insertionMode"
        static let showWaveformInMenuBar = "showWaveformInMenuBar"
    }

    // MARK: - Properties

    @Published var hotkeyCombo: HotkeyCombo = .default
    @Published var recordMode: RecordMode = .hold
    @Published var selectedModelID: String = "whisper-small.en"
    @Published var processingSettings: ProcessingSettings = ProcessingSettings()

    @Published var insertionMode: InsertionMode = .copyToClipboard
    @Published var launchAtLogin: Bool = false
    @Published var maxRecordingDuration: TimeInterval = 120
    @Published var hasCompletedOnboarding: Bool = false
    @Published var appRules: [AppRule] = []
    @Published var showWaveformInMenuBar: Bool = false

    // MARK: - Load/Save

    func load() {
        if let data = defaults.data(forKey: Keys.hotkeyCombo),
           let combo = try? JSONDecoder().decode(HotkeyCombo.self, from: data) {
            hotkeyCombo = combo
        }

        if let modeRaw = defaults.string(forKey: Keys.recordMode),
           let mode = RecordMode(rawValue: modeRaw) {
            recordMode = mode
        }

        if let modelID = defaults.string(forKey: Keys.selectedModelID) {
            selectedModelID = modelID
        }

        if let data = defaults.data(forKey: Keys.processingSettings),
           let settings = try? JSONDecoder().decode(ProcessingSettings.self, from: data) {
            processingSettings = settings
        }

        if let modeRaw = defaults.string(forKey: Keys.insertionMode),
           let mode = InsertionMode(rawValue: modeRaw) {
            insertionMode = mode
        }

        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)

        let duration = defaults.double(forKey: Keys.maxRecordingDuration)
        maxRecordingDuration = duration > 0 ? duration : 120

        if let data = defaults.data(forKey: Keys.appRules),
           let rules = try? JSONDecoder().decode([AppRule].self, from: data) {
            appRules = rules
        }

        showWaveformInMenuBar = defaults.bool(forKey: Keys.showWaveformInMenuBar)

        Self.logger.info("Settings loaded")
    }

    func save() {
        if let data = try? JSONEncoder().encode(hotkeyCombo) {
            defaults.set(data, forKey: Keys.hotkeyCombo)
        }
        defaults.set(recordMode.rawValue, forKey: Keys.recordMode)
        defaults.set(selectedModelID, forKey: Keys.selectedModelID)
        if let data = try? JSONEncoder().encode(processingSettings) {
            defaults.set(data, forKey: Keys.processingSettings)
        }
        defaults.set(insertionMode.rawValue, forKey: Keys.insertionMode)
        defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
        defaults.set(maxRecordingDuration, forKey: Keys.maxRecordingDuration)
        defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        if let data = try? JSONEncoder().encode(appRules) {
            defaults.set(data, forKey: Keys.appRules)
        }
        defaults.set(showWaveformInMenuBar, forKey: Keys.showWaveformInMenuBar)

        Self.logger.info("Settings saved")
    }

    // MARK: - Helpers

    func shouldAutoSend(forBundleID bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return appRules.first { $0.bundleID == bundleID }?.autoSendEnabled ?? false
    }

    func processingSettings(forBundleID bundleID: String?) -> ProcessingSettings {
        guard let bundleID else { return processingSettings }
        return appRules.first { $0.bundleID == bundleID }?.processingOverrides ?? processingSettings
    }
}
