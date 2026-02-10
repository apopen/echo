import UserNotifications
import os.log

/// Sends local notifications for system events (max duration reached, errors, etc.).
enum NotificationHelper {
    private static let logger = Logger(subsystem: "com.echo", category: "NotificationHelper")

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                logger.error("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    static func postMaxDurationReached() {
        let content = UNMutableNotificationContent()
        content.title = "Recording Stopped"
        content.body = "Maximum recording duration reached. Your audio is being transcribed."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "max-duration-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("Failed to post notification: \(error.localizedDescription)")
            }
        }
    }

    static func postTranscriptionError(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Transcription Failed"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "error-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func postInsertionFallback() {
        let content = UNMutableNotificationContent()
        content.title = "Text Copied to Clipboard"
        content.body = "Insertion failed. Your transcript has been copied to the clipboard."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "fallback-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
