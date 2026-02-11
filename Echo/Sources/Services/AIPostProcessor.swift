import Foundation
import os.log

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Wraps the on-device Apple Intelligence language model for transcript cleanup.
/// Only functional on macOS 26+ with Apple Intelligence enabled.
final class AIPostProcessor {
    private static let logger = Logger(subsystem: "com.echo", category: "AIPostProcessor")

    /// Whether the on-device Foundation Models framework is available at runtime.
    static var isAvailable: Bool {
        if #available(macOS 26, *) {
            return true
        }
        return false
    }

    /// Improve a transcript using the on-device language model.
    /// Returns the original text if the model is unavailable or an error occurs.
    func improve(_ text: String) async -> String {
        guard AIPostProcessor.isAvailable else { return text }

        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            do {
                let session = LanguageModelSession(instructions: """
                    You are a transcript cleanup assistant. Clean up the following voice transcript: \
                    fix grammar, remove filler words, fix punctuation, and improve readability. \
                    Preserve the original meaning and tone. Return only the cleaned text with no \
                    commentary or explanation.
                    """)
                let response = try await session.respond(to: text)
                let cleaned = response.content
                guard !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    Self.logger.warning("AI post-processing returned empty text, using original")
                    return text
                }
                Self.logger.info("AI post-processing improved transcript")
                return cleaned
            } catch {
                Self.logger.warning("AI post-processing failed, using original text: \(error)")
                return text
            }
        }
        #endif

        return text
    }
}
