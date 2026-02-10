import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let windowManager = WindowManager()
    let floatingBar = FloatingBarWindow()
    private var statusItem: NSStatusItem?
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        appState.initialize()
        floatingBar.show(appState: appState)

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
            statusBarController = StatusBarController(statusItem: statusItem, appState: appState, delegate: self)
        }
    }

    @objc private func handleWake(_ notification: Notification) {
        appState.handleWake()
    }

    @objc private func handleSleep(_ notification: Notification) {
        appState.handleSleep()
    }
}
