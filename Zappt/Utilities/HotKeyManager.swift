import Foundation
import Carbon.HIToolbox

/// Registers process-wide global hotkeys using the Carbon Hot Key API.
/// This works regardless of which app is focused and needs no extra permission.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var handlerInstalled = false
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1

    private let signature: OSType = 0x434C5052 // 'CLPR'

    private init() {}

    /// Common key codes.
    enum Key: UInt32 {
        case r = 0x0F // kVK_ANSI_R
        case p = 0x23 // kVK_ANSI_P
    }

    /// Modifier mask helpers (Carbon values).
    static let cmdShift = UInt32(cmdKey | shiftKey)

    @discardableResult
    func register(key: Key, modifiers: UInt32, action: @escaping () -> Void) -> UInt32 {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(key.rawValue, modifiers, hotKeyID,
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeyRefs[id] = ref
            actions[id] = action
        }
        return id
    }

    func unregisterAll() {
        for (_, ref) in hotKeyRefs { UnregisterEventHotKey(ref) }
        hotKeyRefs.removeAll()
        actions.removeAll()
    }

    fileprivate func fire(id: UInt32) {
        actions[id]?()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, eventRef, _ -> OSStatus in
            guard let eventRef else { return OSStatus(eventNotHandledErr) }
            var hkID = EventHotKeyID()
            let err = GetEventParameter(eventRef,
                                        EventParamName(kEventParamDirectObject),
                                        EventParamType(typeEventHotKeyID),
                                        nil,
                                        MemoryLayout<EventHotKeyID>.size,
                                        nil,
                                        &hkID)
            if err == noErr {
                DispatchQueue.main.async {
                    HotKeyManager.shared.fire(id: hkID.id)
                }
            }
            return noErr
        }
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, nil)
    }
}
