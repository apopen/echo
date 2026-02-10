import AppKit
import os.log

/// Monitors a global keyboard hotkey for recording activation.
final class HotkeyService {
    private static let logger = Logger(subsystem: "com.echo-fs", category: "HotkeyService")

    var onKeyDown: (() -> Void)?
    var onKeyUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var tapThread: Thread?
    private var registeredCombo: HotkeyCombo = .default
    private var registeredMode: RecordMode = .hold
    private var keyIsDown = false

    func register(combo: HotkeyCombo, mode: RecordMode) {
        unregister()
        registeredCombo = combo
        registeredMode = mode

        let thread = Thread { [weak self] in
            guard let self else { return }
            if self.setupEventTap() {
                Self.logger.info("Hotkey registered via CGEvent tap: keyCode=\(combo.keyCode) (\(combo.displayString))")
                CFRunLoopRun()
            } else {
                Self.logger.error("CGEvent tap failed — need Accessibility/Input Monitoring permission")
            }
        }
        thread.name = "com.echo-fs.event-tap"
        thread.qualityOfService = .userInteractive
        thread.start()
        tapThread = thread
    }

    func unregister() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        tapThread?.cancel()
        tapThread = nil
    }

    func updateMode(_ mode: RecordMode) {
        registeredMode = mode
    }

    // MARK: - CGEvent Tap

    private func setupEventTap() -> Bool {
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, type, event, userInfo -> Unmanaged<CGEvent>? in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<HotkeyService>.fromOpaque(userInfo).takeUnretainedValue()
                let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

                guard keyCode == service.registeredCombo.keyCode else {
                    return Unmanaged.passUnretained(event)
                }

                if type == .keyDown {
                    guard !service.keyIsDown else {
                        return Unmanaged.passUnretained(event)
                    }
                    service.keyIsDown = true
                    service.onKeyDown?()
                } else if type == .keyUp {
                    service.keyIsDown = false
                    service.onKeyUp?()
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) else {
            Self.logger.error("Failed to create CGEvent tap")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        return true
    }
}
