import AppKit
import Carbon.HIToolbox

/// Sends ⌘V to the frontmost app.
///
/// Only the narrow "post events" permission is needed (listed under Accessibility in
/// System Settings), not full Accessibility control of other apps, so this works sandboxed.
enum Paster {
    static var canPostEvents: Bool { CGPreflightPostEventAccess() }

    /// Shows the system prompt the first time; afterwards it just reports the current state.
    @discardableResult
    static func requestAccess() -> Bool {
        CGRequestPostEventAccess()
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

    static func pasteIntoFrontApp() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
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
