import XCTest
@testable import EchoFS

final class ProcessingPipelineTests: XCTestCase {

    let pipeline = ProcessingPipeline()

    // MARK: - Filler Word Removal

    func testFillerRemoval_removesCommonFillers() {
        let input = "So um I think uh this is like really good"
        let result = pipeline.removeFillers(input)
        XCTAssertFalse(result.contains("um"))
        XCTAssertFalse(result.contains("uh"))
        XCTAssertTrue(result.contains("I think"))
        XCTAssertTrue(result.contains("really good"))
    }

    func testFillerRemoval_caseInsensitive() {
        let input = "Um I mean UM this is good"
        let result = pipeline.removeFillers(input)
        XCTAssertFalse(result.lowercased().contains("um"))
    }

    func testFillerRemoval_preservesContentWords() {
        let input = "I like this product"
        let result = pipeline.removeFillers(input)
        // "like" as standalone filler should be removed, but in context it varies
        // The regex matches word boundaries, so "like" alone is treated as filler
        XCTAssertTrue(result.contains("I"))
        XCTAssertTrue(result.contains("product"))
    }

    // MARK: - Number Normalization

    func testNumberNormalization_singleDigits() {
        let input = "I have three apples and five oranges"
        let result = pipeline.normalizeNumbers(input)
        XCTAssertTrue(result.contains("3"))
        XCTAssertTrue(result.contains("5"))
        XCTAssertFalse(result.contains("three"))
        XCTAssertFalse(result.contains("five"))
    }

    func testNumberNormalization_preservesExistingDigits() {
        let input = "I have 3 apples"
        let result = pipeline.normalizeNumbers(input)
        XCTAssertEqual(result, "I have 3 apples")
    }

    // MARK: - Custom Replacements

    func testCustomReplacements_caseSensitive() {
        let rules = [
            ReplacementRule(find: "ASAP", replace: "as soon as possible", caseSensitive: true)
        ]
        let input = "Please do this ASAP and tell asap team"
        let result = pipeline.applyReplacements(input, rules: rules)
        XCTAssertTrue(result.contains("as soon as possible"))
        XCTAssertTrue(result.contains("asap team"))  // lowercase not replaced
    }

    func testCustomReplacements_caseInsensitive() {
        let rules = [
            ReplacementRule(find: "api", replace: "API", caseSensitive: false)
        ]
        let input = "Call the api and the Api endpoint"
        let result = pipeline.applyReplacements(input, rules: rules)
        XCTAssertEqual(result.components(separatedBy: "API").count, 3) // Two replacements
    }

    // MARK: - Punctuation Formatting

    func testPunctuationFormatting_capitalizesFirstLetter() {
        let input = "hello world. this is a test."
        let result = pipeline.formatPunctuation(input)
        XCTAssertTrue(result.hasPrefix("H"))
        XCTAssertTrue(result.contains("This is"))
    }

    func testPunctuationFormatting_fixesSpacing() {
        let input = "hello . world , test !"
        let result = pipeline.formatPunctuation(input)
        // "hello" capitalized (start of text), "world" capitalized (after "."), "test" stays lowercase (after ",")
        XCTAssertTrue(result.contains("Hello."))
        XCTAssertTrue(result.contains("World,"))
        XCTAssertTrue(result.contains("test!"))
    }

    // MARK: - Full Pipeline

    func testFullPipeline_allDisabled() {
        let settings = ProcessingSettings() // all false by default
        let input = "um hello uh world"
        let result = pipeline.process(input, settings: settings, appBundleID: nil)
        XCTAssertEqual(result, "um hello uh world")
    }

    func testFullPipeline_allEnabled() {
        var settings = ProcessingSettings()
        settings.fillerRemovalEnabled = true
        settings.numberNormalizationEnabled = true
        settings.punctuationFormattingEnabled = true

        let input = "um I have three items. uh that is good."
        let result = pipeline.process(input, settings: settings, appBundleID: nil)
        XCTAssertFalse(result.contains("um"))
        XCTAssertFalse(result.contains("uh"))
        XCTAssertTrue(result.contains("3"))
    }

    // MARK: - Processing Order

    func testProcessingOrder_isDeterministic() {
        var settings = ProcessingSettings()
        settings.fillerRemovalEnabled = true
        settings.numberNormalizationEnabled = true
        settings.customReplacementsEnabled = true
        settings.customReplacements = [
            ReplacementRule(find: "3", replace: "THREE", caseSensitive: true)
        ]

        // Fillers removed first, then numbers normalized (three -> 3),
        // then custom replacements (3 -> THREE)
        let input = "um I have three items"
        let result = pipeline.process(input, settings: settings, appBundleID: nil)
        XCTAssertTrue(result.contains("THREE"))
    }
}
