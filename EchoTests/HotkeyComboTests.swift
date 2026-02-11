import XCTest
import Carbon.HIToolbox
@testable import Echo

final class HotkeyComboTests: XCTestCase {

    // MARK: - Default Values

    func testDefaultKeyCode() {
        let combo = HotkeyCombo.default
        XCTAssertEqual(combo.keyCode, UInt16(kVK_PageDown))
    }

    func testDefaultModifiers() {
        let combo = HotkeyCombo.default
        XCTAssertEqual(combo.modifierFlagsRawValue, 0)
    }

    // MARK: - Display String

    func testDisplayStringNoModifiers() {
        var combo = HotkeyCombo()
        combo.keyCode = UInt16(kVK_PageDown)
        combo.modifierFlagsRawValue = 0
        XCTAssertEqual(combo.displayString, "Page Down")
    }

    func testDisplayStringWithCommand() {
        var combo = HotkeyCombo()
        combo.keyCode = UInt16(kVK_ANSI_D)
        combo.cgEventFlags = .maskCommand
        XCTAssertEqual(combo.displayString, "\u{2318}D")
    }

    func testDisplayStringWithMultipleModifiers() {
        var combo = HotkeyCombo()
        combo.keyCode = UInt16(kVK_ANSI_R)
        combo.cgEventFlags = CGEventFlags([.maskControl, .maskShift, .maskCommand])
        XCTAssertEqual(combo.displayString, "\u{2303}\u{21E7}\u{2318}R")
    }

    func testDisplayStringAllModifiers() {
        var combo = HotkeyCombo()
        combo.keyCode = UInt16(kVK_F5)
        combo.cgEventFlags = CGEventFlags([.maskControl, .maskAlternate, .maskShift, .maskCommand])
        XCTAssertEqual(combo.displayString, "\u{2303}\u{2325}\u{21E7}\u{2318}F5")
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        var original = HotkeyCombo()
        original.keyCode = UInt16(kVK_ANSI_K)
        original.cgEventFlags = CGEventFlags([.maskCommand, .maskShift])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(HotkeyCombo.self, from: data)

        XCTAssertEqual(decoded.keyCode, original.keyCode)
        XCTAssertEqual(decoded.modifierFlagsRawValue, original.modifierFlagsRawValue)
        XCTAssertEqual(decoded, original)
    }

    func testBackwardCompatibility_missingModifierFlags() throws {
        // Simulate old data that only has keyCode (no modifierFlagsRawValue)
        let json = """
        {"keyCode": 121}
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(HotkeyCombo.self, from: data)

        XCTAssertEqual(decoded.keyCode, UInt16(kVK_PageDown))
        XCTAssertEqual(decoded.modifierFlagsRawValue, 0)
        XCTAssertEqual(decoded.displayString, "Page Down")
    }

    // MARK: - Relevant Modifiers

    func testRelevantModifiersFiltersNonRelevant() {
        var combo = HotkeyCombo()
        // Set command + some non-relevant flag bits
        combo.modifierFlagsRawValue = CGEventFlags([.maskCommand, .maskNumericPad]).rawValue
        let relevant = combo.relevantModifiers
        XCTAssertTrue(relevant.contains(.maskCommand))
        XCTAssertFalse(relevant.contains(.maskNumericPad))
    }

    // MARK: - KeyCodeNames

    func testKeyCodeNamePageDown() {
        XCTAssertEqual(KeyCodeNames.name(for: UInt16(kVK_PageDown)), "Page Down")
    }

    func testKeyCodeNameLetterA() {
        XCTAssertEqual(KeyCodeNames.name(for: UInt16(kVK_ANSI_A)), "A")
    }

    func testKeyCodeNameF1() {
        XCTAssertEqual(KeyCodeNames.name(for: UInt16(kVK_F1)), "F1")
    }

    func testKeyCodeNameUnknown() {
        // Key code 255 shouldn't be in the map
        let name = KeyCodeNames.name(for: 255)
        XCTAssertEqual(name, "Key 255")
    }

    // MARK: - isValidCombo

    func testValidCombo_standaloneFunctionKey() {
        XCTAssertTrue(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_F5), modifiers: CGEventFlags()))
    }

    func testValidCombo_standalonePageDown() {
        XCTAssertTrue(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_PageDown), modifiers: CGEventFlags()))
    }

    func testValidCombo_standalonePageUp() {
        XCTAssertTrue(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_PageUp), modifiers: CGEventFlags()))
    }

    func testInvalidCombo_standaloneLetterKey() {
        XCTAssertFalse(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_ANSI_A), modifiers: CGEventFlags()))
    }

    func testValidCombo_letterKeyWithModifier() {
        XCTAssertTrue(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_ANSI_A), modifiers: .maskCommand))
    }

    func testInvalidCombo_escapeKey() {
        XCTAssertFalse(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_Escape), modifiers: CGEventFlags()))
    }

    func testInvalidCombo_escapeKeyWithModifier() {
        XCTAssertFalse(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_Escape), modifiers: .maskCommand))
    }

    func testInvalidCombo_returnKey() {
        XCTAssertFalse(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_Return), modifiers: CGEventFlags()))
    }

    func testInvalidCombo_tabKey() {
        XCTAssertFalse(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_Tab), modifiers: CGEventFlags()))
    }

    func testInvalidCombo_deleteKey() {
        XCTAssertFalse(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_Delete), modifiers: CGEventFlags()))
    }

    func testInvalidCombo_modifierOnlyKey() {
        XCTAssertFalse(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_Command), modifiers: .maskCommand))
    }

    func testValidCombo_digitWithModifier() {
        XCTAssertTrue(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_ANSI_1), modifiers: .maskControl))
    }

    func testValidCombo_standaloneHome() {
        XCTAssertTrue(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_Home), modifiers: CGEventFlags()))
    }

    func testValidCombo_standaloneEnd() {
        XCTAssertTrue(KeyCodeNames.isValidCombo(keyCode: UInt16(kVK_End), modifiers: CGEventFlags()))
    }
}
