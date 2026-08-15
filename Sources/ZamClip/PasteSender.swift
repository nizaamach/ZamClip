import AppKit
import ApplicationServices
import Carbon.HIToolbox

enum PasteSender {
    static var hasAccessibilityAccess: Bool {
        AXIsProcessTrusted() || CGPreflightPostEventAccess()
    }

    static func requestAccessibilityAccess() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        _ = CGRequestPostEventAccess()
    }

    static func sendPaste() -> Bool {
        guard hasAccessibilityAccess else { return false }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }

        let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: UInt16(kVK_ANSI_V),
            keyDown: true
        )
        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: UInt16(kVK_ANSI_V),
            keyDown: false
        )

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        return true
    }
}
