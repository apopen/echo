import Foundation
import os.log

/// Manages Privacy Mode state. When enabled, history writes are blocked
/// and existing history is cleared.
final class PrivacyService: ObservableObject {
    private static let logger = Logger(subsystem: "com.echo-fs", category: "PrivacyService")

    @Published var isPrivacyModeEnabled: Bool = false {
        didSet {
            Self.logger.info("Privacy Mode: \(self.isPrivacyModeEnabled ? "enabled" : "disabled")")
        }
    }
}
