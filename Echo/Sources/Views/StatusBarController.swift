import AppKit
import Combine

/// Manages the NSStatusItem (menu bar icon) and its menu.
@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let appState: AppState
    private weak var delegate: AppDelegate?
    private var cancellables = Set<AnyCancellable>()

    init(statusItem: NSStatusItem, appState: AppState, delegate: AppDelegate) {
        self.statusItem = statusItem
        self.appState = appState
        self.delegate = delegate
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
    }

    private func updateStatusIcon() {
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
