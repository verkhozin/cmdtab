import AppKit
import Carbon.HIToolbox

/// Registers a global hotkey via Carbon's RegisterEventHotKey.
///
/// Why Carbon and not CGEventTap or NSEvent.addGlobalMonitor:
/// - RegisterEventHotKey works WITHOUT Accessibility permission and is the
///   canonical way Apple's own apps register global hotkeys.
/// - CGEventTap requires Accessibility access and intercepts the event
///   stream globally — overkill and a permissions hurdle for a hotkey.
/// - NSEvent.addGlobalMonitor cannot consume the event, so the original
///   Cmd+Tab still fires.
@MainActor
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let onTrigger: () -> Void

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    /// Default: Option+Y. Picked for testing because Y is essentially
    /// unused as a system shortcut. Will become user-configurable.
    func registerDefault() {
        register(keyCode: UInt32(kVK_ANSI_Y), modifiers: UInt32(optionKey))
    }

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, eventRef, userData -> OSStatus in
            guard let userData, let eventRef else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            GetEventParameter(eventRef,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              nil,
                              MemoryLayout<EventHotKeyID>.size,
                              nil,
                              &hotKeyID)
            DispatchQueue.main.async { manager.onTrigger() }
            return noErr
        }, 1, &eventType, selfPtr, &eventHandlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x434D4442), id: 1) // 'CMDB'
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
        hotKeyRef = nil
        eventHandlerRef = nil
    }
}
