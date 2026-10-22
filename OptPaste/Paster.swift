import AppKit
import Carbon.HIToolbox
import OSLog

/// Sends ⌘V (or another key combination) to the frontmost app.
///
/// Only the narrow "post events" permission is needed (listed under Accessibility in
/// System Settings), not full Accessibility control of other apps.
enum Paster {
    static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OptPaste", category: "paste")

    static var canPostEvents: Bool { CGPreflightPostEventAccess() }

    /// Shows the system prompt the first time; afterwards it just reports the current state.
    @discardableResult
    static func requestAccess() -> Bool {
        CGRequestPostEventAccess()
    }

    /// macOS may only apply a newly granted permission to a fresh process.
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }

    static func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    static func openPasteSettings() {
        openPrivacyPane("Privacy_Pasteboard")
    }

    private static func openPrivacyPane(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Brings `app` back to the front, waits until it actually is, then sends ⌘V.
    static func paste(into app: NSRunningApplication) {
        log.info("Colando em \(app.bundleIdentifier ?? "?", privacy: .public); permissão: \(canPostEvents, privacy: .public)")
        app.activate()
        waitUntilFrontmost(app, attemptsLeft: 20)
    }

    private static func waitUntilFrontmost(_ app: NSRunningApplication, attemptsLeft: Int) {
        let isFront = NSWorkspace.shared.frontmostApplication == app
        guard isFront || attemptsLeft == 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
                waitUntilFrontmost(app, attemptsLeft: attemptsLeft - 1)
            }
            return
        }
        if !isFront {
            log.error("O app de destino não voltou ao primeiro plano; enviando ⌘V mesmo assim")
        }
        // Give the target a moment to restore its key window and text focus.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { post(kVK_ANSI_V, modifiers: .maskCommand) }
    }

    /// Sends a key with the given modifiers to the frontmost app, e.g. ⌘V or ⌥⌘V.
    static func post(_ key: Int, modifiers: CGEventFlags) {
        let source = CGEventSource(stateID: .combinedSessionState)
        // Keep the user's physical keys (e.g. a still-held ⌥ from the shortcut) out of the event.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let keyCode = CGKeyCode(key)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            log.error("Não foi possível criar os eventos de teclado")
            return
        }
        // Device-dependent "left key" bits (⌘ 0x08, ⌥ 0x20); some apps ignore modifiers without them.
        var flags = modifiers
        if modifiers.contains(.maskCommand) { flags.insert(CGEventFlags(rawValue: 0x08)) }
        if modifiers.contains(.maskAlternate) { flags.insert(CGEventFlags(rawValue: 0x20)) }
        down.flags = flags
        up.flags = flags
        // Posted at session level, where synthetic events are expected.
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        log.info("Tecla \(key, privacy: .public) enviada com modificadores \(modifiers.rawValue, privacy: .public)")
    }
}

/// macOS 15.4+ lets users decide whether apps may read the pasteboard without asking.
enum PasteAccess {
    case allowed, ask, denied

    static var current: PasteAccess {
        guard #available(macOS 15.4, *) else { return .allowed }
        switch NSPasteboard.general.accessBehavior {
        case .ask: return .ask
        case .alwaysDeny: return .denied
        default: return .allowed
        }
    }
}
