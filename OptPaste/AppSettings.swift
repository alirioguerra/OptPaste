import AppKit
import Carbon.HIToolbox
import Observation

/// A global keyboard shortcut expressed in Carbon terms, ready for `RegisterEventHotKey`.
struct Shortcut: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var keyLabel: String

    static let `default` = Shortcut(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(optionKey), keyLabel: "V")
    static let defaultCut = Shortcut(keyCode: UInt32(kVK_ANSI_X), carbonModifiers: UInt32(cmdKey), keyLabel: "X")
    static let commandV = Shortcut(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(cmdKey), keyLabel: "V")

    init(keyCode: UInt32, carbonModifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keyLabel = keyLabel
    }

    init(event: NSEvent) {
        let flags = event.modifierFlags
        var mods: UInt32 = 0
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        self.init(keyCode: UInt32(event.keyCode), carbonModifiers: mods, keyLabel: Self.label(for: event))
    }

    var displayString: String {
        keycaps.map(\.symbol).joined()
    }

    /// The keys as printed on a Mac keyboard, modifiers first in Apple's order.
    var keycaps: [(symbol: String, name: String?)] {
        let modifiers: [(Int, String, String)] = [
            (controlKey, "⌃", "control"), (optionKey, "⌥", "option"),
            (shiftKey, "⇧", "shift"), (cmdKey, "⌘", "command"),
        ]
        return modifiers
            .filter { carbonModifiers & UInt32($0.0) != 0 }
            .map { (symbol: $0.1, name: $0.2) } + [(symbol: keyLabel, name: nil)]
    }

    private static func label(for event: NSEvent) -> String {
        let special: [Int: String] = [
            kVK_Space: String(localized: "Space"), kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
            kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→",
            kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let label = special[Int(event.keyCode)] { return label }
        return event.charactersIgnoringModifiers?.uppercased() ?? "?"
    }
}

@Observable
final class AppSettings {
    private enum Key {
        static let shortcut = "shortcut"
        static let historyLimit = "historyLimit"
        static let autoPaste = "autoPaste"
        static let savePasswords = "savePasswords"
        static let didCompleteOnboarding = "didCompleteOnboarding"
        static let finderCut = "finderCut"
        static let cutShortcut = "cutShortcut"
    }

    static let historyLimitOptions = [10, 25, 50, 100, 200]

    var shortcut: Shortcut {
        didSet {
            if let data = try? JSONEncoder().encode(shortcut) {
                UserDefaults.standard.set(data, forKey: Key.shortcut)
            }
        }
    }

    var historyLimit: Int {
        didSet { UserDefaults.standard.set(historyLimit, forKey: Key.historyLimit) }
    }

    /// Sends ⌘V after choosing an item. Off means the item is only copied.
    var autoPaste: Bool {
        didSet { UserDefaults.standard.set(autoPaste, forKey: Key.autoPaste) }
    }

    /// Also keep copies that password managers mark as concealed.
    var savePasswords: Bool {
        didSet { UserDefaults.standard.set(savePasswords, forKey: Key.savePasswords) }
    }

    var didCompleteOnboarding: Bool {
        didSet { UserDefaults.standard.set(didCompleteOnboarding, forKey: Key.didCompleteOnboarding) }
    }

    /// In Finder, the cut shortcut marks the selected files as cut and the next ⌘V moves them.
    var finderCut: Bool {
        didSet { UserDefaults.standard.set(finderCut, forKey: Key.finderCut) }
    }

    var cutShortcut: Shortcut {
        didSet {
            if let data = try? JSONEncoder().encode(cutShortcut) {
                UserDefaults.standard.set(data, forKey: Key.cutShortcut)
            }
        }
    }

    init() {
        let defaults = UserDefaults.standard
        shortcut = defaults.data(forKey: Key.shortcut)
            .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .default
        let limit = defaults.integer(forKey: Key.historyLimit)
        historyLimit = limit > 0 ? limit : 50
        autoPaste = defaults.object(forKey: Key.autoPaste) as? Bool ?? true
        savePasswords = defaults.object(forKey: Key.savePasswords) as? Bool ?? true
        didCompleteOnboarding = defaults.bool(forKey: Key.didCompleteOnboarding)
        finderCut = defaults.object(forKey: Key.finderCut) as? Bool ?? true
        cutShortcut = defaults.data(forKey: Key.cutShortcut)
            .flatMap { try? JSONDecoder().decode(Shortcut.self, from: $0) } ?? .defaultCut
    }
}
