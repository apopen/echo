import AppKit
import SwiftUI
import Combine
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let windowManager = WindowManager()
    let floatingBar = FloatingBarWindow()
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var statusItem: NSStatusItem?
    private var statusBarController: StatusBarController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        appState.initialize()
        floatingBar.show(appState: appState)

        // Hide floating bar if waveform is shown in menu bar
        if appState.settingsStore.showWaveformInMenuBar {
            floatingBar.hide()
        }

        // Observe setting changes
        appState.settingsStore.$showWaveformInMenuBar
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showInMenuBar in
                if showInMenuBar {
                    self?.floatingBar.hide()
                } else {
                    self?.floatingBar.unhide()
                }
            }
            .store(in: &cancellables)

        // Show onboarding on first launch
        if !appState.hasCompletedOnboarding {
            windowManager.showOnboarding(appState: appState)
        }

        // Register for sleep/wake notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.shutdown()
    }

    func showSettings() {
        windowManager.showSettings(appState: appState)
    }

    func showOnboarding() {
        windowManager.showOnboarding(appState: appState)
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let statusItem {
            statusBarController = StatusBarController(statusItem: statusItem, appState: appState, delegate: self, updaterController: updaterController)
        }
    }

    @objc private func handleWake(_ notification: Notification) {
        appState.handleWake()
    }

    @objc private func handleSleep(_ notification: Notification) {
        appState.handleSleep()
    }
}
