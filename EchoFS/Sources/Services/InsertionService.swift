import AppKit
import os.log

/// Copies transcribed text to the system clipboard.
final class InsertionService {
    private static let logger = Logger(subsystem: "com.echo-fs", category: "InsertionService")

    /// Copy text to the clipboard.
    func insert(_ text: String, autoSend: Bool) async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        Self.logger.info("Transcription copied to clipboard (\(text.count) chars)")
    }
}
