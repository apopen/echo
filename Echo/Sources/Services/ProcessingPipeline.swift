import Foundation
import os.log

/// Applies text transforms in a deterministic order:
/// 1. Filler word removal
/// 2. Number normalization
/// 3. Custom replacements
/// 4. Punctuation/capitalization formatting
final class ProcessingPipeline {
    private static let logger = Logger(subsystem: "com.echo", category: "ProcessingPipeline")

    /// Default filler words to remove.
    static let defaultFillerWords: Set<String> = [
        "um", "uh", "er", "ah", "like", "you know", "I mean",
        "basically", "actually", "literally", "so", "well",
        "hmm", "erm", "right"
    ]

    /// Spoken number words to digit mappings.
    private static let numberWords: [(String, String)] = [
        ("zero", "0"), ("one", "1"), ("two", "2"), ("three", "3"),
        ("four", "4"), ("five", "5"), ("six", "6"), ("seven", "7"),
        ("eight", "8"), ("nine", "9"), ("ten", "10"),
        ("eleven", "11"), ("twelve", "12"), ("thirteen", "13"),
        ("fourteen", "14"), ("fifteen", "15"), ("sixteen", "16"),
        ("seventeen", "17"), ("eighteen", "18"), ("nineteen", "19"),
        ("twenty", "20"), ("thirty", "30"), ("forty", "40"),
        ("fifty", "50"), ("sixty", "60"), ("seventy", "70"),
        ("eighty", "80"), ("ninety", "90"),
        ("hundred", "100"), ("thousand", "1000"),
    ]

    /// Process text through the enabled pipeline stages.
    /// - Parameters:
    ///   - text: Raw transcribed text.
    ///   - settings: Processing settings (may be overridden by app rules).
    ///   - appBundleID: The focused app's bundle ID for per-app rule resolution.
    /// - Returns: Processed text.
    func process(_ text: String, settings: ProcessingSettings, appBundleID: String?) -> String {
        var result = text

        // Stage 1: Filler word removal
        if settings.fillerRemovalEnabled {
            result = removeFillers(result)
        }

        // Stage 2: Number normalization
        if settings.numberNormalizationEnabled {
            result = normalizeNumbers(result)
        }

        // Stage 3: Custom replacements
        if settings.customReplacementsEnabled {
            result = applyReplacements(result, rules: settings.customReplacements)
        }

        // Stage 4: Punctuation/capitalization
        if settings.punctuationFormattingEnabled {
            result = formatPunctuation(result)
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Stage Implementations

    func removeFillers(_ text: String) -> String {
        var result = text
        // Remove multi-word fillers first (longer patterns first)
        let sortedFillers = Self.defaultFillerWords.sorted { $0.count > $1.count }
        for filler in sortedFillers {
            // Match whole word/phrase boundaries
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: filler))\\b,?\\s*"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }
        // Clean up double spaces
        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }
        return result
    }

    func normalizeNumbers(_ text: String) -> String {
        var result = text
        for (word, digit) in Self.numberWords {
            let pattern = "\\b\(word)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: digit
                )
            }
        }
        return result
    }

    func applyReplacements(_ text: String, rules: [ReplacementRule]) -> String {
        var result = text
        for rule in rules {
            if rule.caseSensitive {
                result = result.replacingOccurrences(of: rule.find, with: rule.replace)
            } else {
                // Case-insensitive replacement using regex
                let pattern = NSRegularExpression.escapedPattern(for: rule.find)
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: NSRange(result.startIndex..., in: result),
                        withTemplate: NSRegularExpression.escapedTemplate(for: rule.replace)
                    )
                }
            }
        }
        return result
    }

    func formatPunctuation(_ text: String) -> String {
        var result = text

        // Capitalize first letter of sentences
        let sentenceEnders: CharacterSet = CharacterSet(charactersIn: ".!?")
        var capitalize = true
        var formatted = ""
        for char in result {
            if capitalize && char.isLetter {
                formatted.append(char.uppercased())
                capitalize = false
            } else {
                formatted.append(char)
            }
            if let scalar = char.unicodeScalars.first, sentenceEnders.contains(scalar) {
                capitalize = true
            }
        }
        result = formatted

        // Fix spacing around punctuation
        result = result.replacingOccurrences(of: " .", with: ".")
        result = result.replacingOccurrences(of: " ,", with: ",")
        result = result.replacingOccurrences(of: " !", with: "!")
        result = result.replacingOccurrences(of: " ?", with: "?")

        return result
    }
}
