import AppKit
import Carbon.HIToolbox
import OSLog

/// Sends ⌘V to the frontmost app.
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { postCommandV() }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        // Keep the user's physical keys (e.g. a still-held ⌥ from the shortcut) out of the event.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let keyCode = CGKeyCode(kVK_ANSI_V)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            log.error("Não foi possível criar os eventos de teclado")
            return
        }
        // 0x08 is the device-dependent "left ⌘" bit; some apps ignore ⌘ without it.
        let command = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x08)
        down.flags = command
        up.flags = command
        // Posted at session level, where synthetic events are expected.
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
        log.info("⌘V enviado")
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

    var message: String? {
        switch self {
        case .allowed: nil
        case .ask: "O macOS vai pedir confirmação a cada cópia. Em Privacidade e Segurança › Colar, escolha “Permitir” para o OptPaste."
        case .denied: "O acesso à área de transferência está negado. Permita o OptPaste em Privacidade e Segurança › Colar."
        }
    }
}
