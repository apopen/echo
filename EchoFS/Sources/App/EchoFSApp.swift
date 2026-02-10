import SwiftUI

@main
struct EchoFSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar app — no main window. Settings and onboarding
        // are managed via WindowManager in AppDelegate.
        Settings {
            EmptyView()
        }
    }
}
