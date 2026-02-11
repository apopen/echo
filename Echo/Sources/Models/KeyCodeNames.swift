import Carbon.HIToolbox

/// Maps Carbon virtual key codes to human-readable names and provides combo validation.
enum KeyCodeNames {

    // MARK: - Key Name Lookup

    static func name(for keyCode: UInt16) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
    }

    // MARK: - Validation

    /// Returns true if the key code + modifier combination is acceptable as a hotkey.
    /// - Standalone function keys, Page Up/Down, Home, End, Forward Delete are allowed without modifiers.
    /// - Escape, Return, Tab, Delete (backspace) are always rejected.
    /// - Regular keys (letters, digits, punctuation) require at least one modifier.
    static func isValidCombo(keyCode: UInt16, modifiers: CGEventFlags) -> Bool {
        // Reject modifier-only key codes
        if modifierKeyCodes.contains(keyCode) { return false }

        // Reject always-forbidden keys
        if forbiddenKeyCodes.contains(keyCode) { return false }

        // Standalone-capable keys need no modifier
        if standaloneCapableKeyCodes.contains(keyCode) { return true }

        // Everything else requires at least one modifier
        let relevant = modifiers.intersection(HotkeyCombo.relevantModifiersMask)
        return !relevant.isEmpty
    }

    // MARK: - Modifier Key Codes

    static let modifierKeyCodes: Set<UInt16> = [
        UInt16(kVK_Command),       // 55
        UInt16(kVK_Shift),         // 56
        UInt16(kVK_Option),        // 58
        UInt16(kVK_Control),       // 59
        UInt16(kVK_RightCommand),  // 54
        UInt16(kVK_RightShift),    // 60
        UInt16(kVK_RightOption),   // 61
        UInt16(kVK_RightControl),  // 62
        UInt16(kVK_Function),      // 63
        UInt16(kVK_CapsLock),      // 57
    ]

    // MARK: - Private

    private static let forbiddenKeyCodes: Set<UInt16> = [
        UInt16(kVK_Escape),        // 53
        UInt16(kVK_Return),        // 36
        UInt16(kVK_Tab),           // 48
        UInt16(kVK_Delete),        // 51 (backspace)
        UInt16(kVK_ANSI_KeypadEnter), // 76
    ]

    private static let standaloneCapableKeyCodes: Set<UInt16> = [
        UInt16(kVK_F1), UInt16(kVK_F2), UInt16(kVK_F3), UInt16(kVK_F4),
        UInt16(kVK_F5), UInt16(kVK_F6), UInt16(kVK_F7), UInt16(kVK_F8),
        UInt16(kVK_F9), UInt16(kVK_F10), UInt16(kVK_F11), UInt16(kVK_F12),
        UInt16(kVK_F13), UInt16(kVK_F14), UInt16(kVK_F15), UInt16(kVK_F16),
        UInt16(kVK_F17), UInt16(kVK_F18), UInt16(kVK_F19), UInt16(kVK_F20),
        UInt16(kVK_PageUp), UInt16(kVK_PageDown),
        UInt16(kVK_Home), UInt16(kVK_End),
        UInt16(kVK_ForwardDelete),
    ]

    private static let keyNames: [UInt16: String] = [
        // Letters
        UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_B): "B", UInt16(kVK_ANSI_C): "C",
        UInt16(kVK_ANSI_D): "D", UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_F): "F",
        UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_H): "H", UInt16(kVK_ANSI_I): "I",
        UInt16(kVK_ANSI_J): "J", UInt16(kVK_ANSI_K): "K", UInt16(kVK_ANSI_L): "L",
        UInt16(kVK_ANSI_M): "M", UInt16(kVK_ANSI_N): "N", UInt16(kVK_ANSI_O): "O",
        UInt16(kVK_ANSI_P): "P", UInt16(kVK_ANSI_Q): "Q", UInt16(kVK_ANSI_R): "R",
        UInt16(kVK_ANSI_S): "S", UInt16(kVK_ANSI_T): "T", UInt16(kVK_ANSI_U): "U",
        UInt16(kVK_ANSI_V): "V", UInt16(kVK_ANSI_W): "W", UInt16(kVK_ANSI_X): "X",
        UInt16(kVK_ANSI_Y): "Y", UInt16(kVK_ANSI_Z): "Z",

        // Digits
        UInt16(kVK_ANSI_0): "0", UInt16(kVK_ANSI_1): "1", UInt16(kVK_ANSI_2): "2",
        UInt16(kVK_ANSI_3): "3", UInt16(kVK_ANSI_4): "4", UInt16(kVK_ANSI_5): "5",
        UInt16(kVK_ANSI_6): "6", UInt16(kVK_ANSI_7): "7", UInt16(kVK_ANSI_8): "8",
        UInt16(kVK_ANSI_9): "9",

        // Function keys
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
        UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
        UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
        UInt16(kVK_F13): "F13", UInt16(kVK_F14): "F14", UInt16(kVK_F15): "F15",
        UInt16(kVK_F16): "F16", UInt16(kVK_F17): "F17", UInt16(kVK_F18): "F18",
        UInt16(kVK_F19): "F19", UInt16(kVK_F20): "F20",

        // Navigation
        UInt16(kVK_UpArrow): "Up", UInt16(kVK_DownArrow): "Down",
        UInt16(kVK_LeftArrow): "Left", UInt16(kVK_RightArrow): "Right",
        UInt16(kVK_PageUp): "Page Up", UInt16(kVK_PageDown): "Page Down",
        UInt16(kVK_Home): "Home", UInt16(kVK_End): "End",

        // Special keys
        UInt16(kVK_Space): "Space",
        UInt16(kVK_ForwardDelete): "Forward Delete",

        // Punctuation / symbols (ANSI layout)
        UInt16(kVK_ANSI_Minus): "-", UInt16(kVK_ANSI_Equal): "=",
        UInt16(kVK_ANSI_LeftBracket): "[", UInt16(kVK_ANSI_RightBracket): "]",
        UInt16(kVK_ANSI_Backslash): "\\", UInt16(kVK_ANSI_Semicolon): ";",
        UInt16(kVK_ANSI_Quote): "'", UInt16(kVK_ANSI_Comma): ",",
        UInt16(kVK_ANSI_Period): ".", UInt16(kVK_ANSI_Slash): "/",
        UInt16(kVK_ANSI_Grave): "`",

        // Keypad
        UInt16(kVK_ANSI_Keypad0): "Keypad 0", UInt16(kVK_ANSI_Keypad1): "Keypad 1",
        UInt16(kVK_ANSI_Keypad2): "Keypad 2", UInt16(kVK_ANSI_Keypad3): "Keypad 3",
        UInt16(kVK_ANSI_Keypad4): "Keypad 4", UInt16(kVK_ANSI_Keypad5): "Keypad 5",
        UInt16(kVK_ANSI_Keypad6): "Keypad 6", UInt16(kVK_ANSI_Keypad7): "Keypad 7",
        UInt16(kVK_ANSI_Keypad8): "Keypad 8", UInt16(kVK_ANSI_Keypad9): "Keypad 9",
        UInt16(kVK_ANSI_KeypadDecimal): "Keypad .",
        UInt16(kVK_ANSI_KeypadMultiply): "Keypad *",
        UInt16(kVK_ANSI_KeypadPlus): "Keypad +",
        UInt16(kVK_ANSI_KeypadMinus): "Keypad -",
        UInt16(kVK_ANSI_KeypadDivide): "Keypad /",
        UInt16(kVK_ANSI_KeypadEquals): "Keypad =",
        UInt16(kVK_ANSI_KeypadClear): "Keypad Clear",
    ]
}
