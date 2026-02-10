import AppKit
import SwiftUI

/// A borderless, always-on-top window that floats just above the dock.
@MainActor
final class FloatingBarWindow {
    private var window: NSWindow?

    func show(appState: AppState) {
        guard window == nil else { return }

        let barView = FloatingBarView(appState: appState)
        let hostingView = NSHostingView(rootView: barView)

        // Window is sized for the largest state (recording).
        // The SwiftUI view animates within this fixed frame.
        let windowWidth: CGFloat = 220
        let windowHeight: CGFloat = 40

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        w.contentView = hostingView
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.level = .statusBar
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.isReleasedWhenClosed = false
        w.ignoresMouseEvents = true

        positionAboveDock(w)
        w.orderFrontRegardless()
        window = w

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if let w = self?.window {
                self?.positionAboveDock(w)
            }
        }
    }

    private func positionAboveDock(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame

        let dockHeight = visibleFrame.minY - screenFrame.minY
        let barY = screenFrame.minY + dockHeight + 8
        let barX = screenFrame.midX - window.frame.width / 2

        window.setFrameOrigin(NSPoint(x: barX, y: barY))
    }
}
