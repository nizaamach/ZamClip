import AppKit
import Carbon.HIToolbox
import Foundation

enum GlobalHotKeyError: Error {
    case unableToInstallHandler(OSStatus)
    case unableToRegisterHotKey(OSStatus)
}

final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let action: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) throws {
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                hotKey.action()
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandlerRef
        )
        guard handlerStatus == noErr else {
            throw GlobalHotKeyError.unableToInstallHandler(handlerStatus)
        }

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), id: 1)
        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            if let eventHandlerRef {
                RemoveEventHandler(eventHandlerRef)
            }
            throw GlobalHotKeyError.unableToRegisterHotKey(registerStatus)
        }
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        return modifiers
    }

    static func keyLabel(for event: NSEvent) -> String {
        switch event.keyCode {
        case UInt16(kVK_Return): return "Return"
        case UInt16(kVK_Tab): return "Tab"
        case UInt16(kVK_Space): return "Space"
        case UInt16(kVK_Delete): return "Delete"
        case UInt16(kVK_Escape): return "Escape"
        case UInt16(kVK_UpArrow): return "Up"
        case UInt16(kVK_DownArrow): return "Down"
        case UInt16(kVK_LeftArrow): return "Left"
        case UInt16(kVK_RightArrow): return "Right"
        default:
            return event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
