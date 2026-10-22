import AppKit
import Carbon.HIToolbox
import OSLog

/// Cut and paste for files in Finder.
///
/// Finder has no "cut" for files: you copy (⌘C) and then move with ⌥⌘V. While Finder is in front,
/// the cut shortcut (⌘X by default) sends ⌘C and remembers that the copied files were cut; the next
/// ⌘V is then sent as ⌥⌘V, so Finder moves them. Copying anything else in between cancels the cut.
///
/// Both keys are Carbon hotkeys registered only while Finder is frontmost (and ⌘V only while a cut is
/// pending), so other apps never see a difference.
final class FinderCut {
    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OptPaste", category: "finder-cut")
    private static let finder = "com.apple.finder"
    /// Time for Finder to handle a posted key before we look at the pasteboard or re-arm our hotkeys.
    private static let settleDelay = 0.15

    private let settings: AppSettings
    private let cutKey = HotKeyManager(id: 2)
    private let pasteKey = HotKeyManager(id: 3)
    /// Pasteboard change count right after a cut. The cut is pending while the pasteboard still has it.
    private var cutChangeCount: Int?
    private var isBusy = false
    private var activationObserver: NSObjectProtocol?

    init(settings: AppSettings) {
        self.settings = settings
        cutKey.onPress = { [unowned self] in cut() }
        pasteKey.onPress = { [unowned self] in paste() }
    }

    func start() {
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        update()
    }

    private var isPending: Bool {
        cutChangeCount != nil && cutChangeCount == NSPasteboard.general.changeCount
    }

    /// Registers or releases the hotkeys for the current app, setting and permission.
    func update() {
        guard !isBusy else { return }
        let active = settings.finderCut
            && Paster.canPostEvents
            && NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Self.finder
        if active {
            if !cutKey.register(settings.cutShortcut) {
                Self.log.error("Não foi possível registrar o atalho de recortar")
            }
        } else {
            cutKey.unregister()
        }
        if active && isPending {
            pasteKey.register(.commandV)
        } else {
            pasteKey.unregister()
        }
    }

    private func cut() {
        isBusy = true
        cutKey.unregister()
        let pasteboard = NSPasteboard.general
        let before = pasteboard.changeCount
        Paster.post(kVK_ANSI_C, modifiers: .maskCommand)

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) { [self] in
            let copiedFiles = pasteboard.changeCount != before
                && pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
            if copiedFiles {
                cutChangeCount = pasteboard.changeCount
                Self.log.info("Arquivos recortados")
                finish()
            } else {
                // Not files, e.g. a name being edited: let Finder cut the text itself.
                cutChangeCount = nil
                Paster.post(kVK_ANSI_X, modifiers: .maskCommand)
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) { self.finish() }
            }
        }
    }

    private func paste() {
        isBusy = true
        pasteKey.unregister()
        let move = isPending
        cutChangeCount = nil
        Paster.post(kVK_ANSI_V, modifiers: move ? [.maskCommand, .maskAlternate] : .maskCommand)
        if move { Self.log.info("Arquivos movidos") }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.settleDelay) { [self] in finish() }
    }

    private func finish() {
        isBusy = false
        update()
    }
}
