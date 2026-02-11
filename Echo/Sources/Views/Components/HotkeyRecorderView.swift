import SwiftUI
import Carbon.HIToolbox

/// A key recorder component that lets users set a custom hotkey combination.
/// Shows the current combo in idle state with a "Record" button.
/// In recording state, captures the next keypress and validates it.
struct HotkeyRecorderView: View {
    @Binding var combo: HotkeyCombo
    var onChanged: (() -> Void)?

    @State private var isRecording = false
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            if isRecording {
                Text("Press a key...")
                    .foregroundColor(.secondary)
                    .frame(minWidth: 120)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.accentColor, lineWidth: 2)
                    )

                Button("Cancel") {
                    stopRecording()
                }
            } else {
                Text(combo.displayString)
                    .bold()
                    .frame(minWidth: 120)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                    )

                Button("Record") {
                    startRecording()
                }
            }
        }
        .onDisappear {
            removeMonitors()
        }
    }

    // MARK: - Recording

    private func startRecording() {
        isRecording = true

        // Ensure the app is frontmost so the local monitor can swallow events
        NSApp.activate(ignoringOtherApps: true)

        // Local monitor — captures events when Echo is focused and can swallow them
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
            return nil // swallow the event
        }

        // Global monitor — captures events when another app is focused
        // (cannot swallow events, but still lets the user set the hotkey)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
        }
    }

    private func stopRecording() {
        isRecording = false
        removeMonitors()
    }

    private func removeMonitors() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = UInt16(event.keyCode)

        // Bare Escape cancels recording
        if keyCode == UInt16(kVK_Escape) && event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .function]).isEmpty {
            stopRecording()
            return
        }

        // Ignore modifier-only presses
        if KeyCodeNames.modifierKeyCodes.contains(keyCode) {
            return
        }

        let cgFlags = nsEventFlagsToCGEventFlags(event.modifierFlags)

        guard KeyCodeNames.isValidCombo(keyCode: keyCode, modifiers: cgFlags) else {
            return
        }

        var newCombo = HotkeyCombo()
        newCombo.keyCode = keyCode
        newCombo.cgEventFlags = cgFlags.intersection(HotkeyCombo.relevantModifiersMask)

        combo = newCombo
        stopRecording()
        onChanged?()
    }

    // MARK: - Flag Conversion

    private func nsEventFlagsToCGEventFlags(_ flags: NSEvent.ModifierFlags) -> CGEventFlags {
        var result = CGEventFlags()
        if flags.contains(.command)  { result.insert(.maskCommand) }
        if flags.contains(.shift)    { result.insert(.maskShift) }
        if flags.contains(.option)   { result.insert(.maskAlternate) }
        if flags.contains(.control)  { result.insert(.maskControl) }
        return result
    }
}
