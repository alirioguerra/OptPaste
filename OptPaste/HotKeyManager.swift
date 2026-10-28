import Carbon.HIToolbox

/// Registers a system-wide hotkey through Carbon. Unlike event taps, this needs no
/// Accessibility permission and the key press is not delivered to the frontmost app.
///
/// Each instance owns one hotkey; `shared` is the one that opens the history.
final class HotKeyManager {
    static let shared = HotKeyManager(id: 1)

    var onPress: (() -> Void)?

    private let id: UInt32
    private var hotKeyRef: EventHotKeyRef?

    private static var instances: [UInt32: HotKeyManager] = [:]
    private static var handlerRef: EventHandlerRef?

    init(id: UInt32) {
        precondition(Self.instances[id] == nil, "hotkey id \(id) already in use")
        self.id = id
        Self.instances[id] = self
    }

    var isRegistered: Bool { hotKeyRef != nil }

    @discardableResult
    func register(_ shortcut: Shortcut) -> Bool {
        unregister()
        Self.installHandlerIfNeeded()
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F50_5354), id: id) // "OPST"
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.carbonModifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
    }

    private static func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
            )
            // Carbon dispatches application-target events on the main thread.
            MainActor.assumeIsolated { HotKeyManager.instances[hotKeyID.id]?.onPress?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }
}
