import Foundation
import Carbon.HIToolbox

/// Represents the keyboard hotkey for recording activation.
struct HotkeyCombo: Codable, Equatable {
    var keyCode: UInt16 = UInt16(kVK_PageDown) // 121
    var modifierFlagsRawValue: UInt64 = 0

    static let `default` = HotkeyCombo()

    // Custom Decodable to handle old data missing the modifierFlagsRawValue key.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        modifierFlagsRawValue = try container.decodeIfPresent(UInt64.self, forKey: .modifierFlagsRawValue) ?? 0
    }

    init() {}

    /// The four modifier flags we care about for hotkey matching.
    static let relevantModifiersMask = CGEventFlags([
        .maskCommand, .maskShift, .maskAlternate, .maskControl,
    ])

    // MARK: - CGEventFlags bridging

    var cgEventFlags: CGEventFlags {
        get { CGEventFlags(rawValue: modifierFlagsRawValue) }
        set { modifierFlagsRawValue = newValue.rawValue }
    }

    /// Stored flags masked to only the four relevant modifiers.
    var relevantModifiers: CGEventFlags {
        cgEventFlags.intersection(Self.relevantModifiersMask)
    }

    // MARK: - Display

    var displayString: String {
        var parts: [String] = []

        let flags = relevantModifiers
        if flags.contains(.maskControl)   { parts.append("\u{2303}") }  // ⌃
        if flags.contains(.maskAlternate)  { parts.append("\u{2325}") } // ⌥
        if flags.contains(.maskShift)      { parts.append("\u{21E7}") } // ⇧
        if flags.contains(.maskCommand)    { parts.append("\u{2318}") } // ⌘

        parts.append(KeyCodeNames.name(for: keyCode))
        return parts.joined()
    }
}
