import AppKit
import os.log

/// Inserts transcribed text via clipboard copy or paste-in-place.
final class InsertionService {
    private static let logger = Logger(subsystem: "com.echo", category: "InsertionService")

    /// Insert text using the specified mode.
    func insert(_ text: String, autoSend: Bool, mode: InsertionMode) async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        switch mode {
        case .copyToClipboard:
            Self.logger.info("Transcription copied to clipboard (\(text.count) chars)")

        case .pasteInPlace:
            // Small delay to ensure the pasteboard is ready and the target app is focused
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            simulatePaste()
            Self.logger.info("Transcription pasted in place (\(text.count) chars)")
        }
    }

    // MARK: - Private

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),  // 0x09 = kVK_ANSI_V
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else {
            Self.logger.error("Failed to create CGEvent for paste simulation")
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
