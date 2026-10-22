import AppKit
import Carbon.HIToolbox
import Observation
import OSLog
import SwiftUI

@Observable
final class PanelState {
    var selectedIndex = 0
}

/// Borderless panel that takes keyboard focus without activating OptPaste, so the app
/// the user was typing in stays frontmost and can receive the paste.
final class HistoryPanel: NSPanel {
    init(size: NSSize) {
        super.init(contentRect: NSRect(origin: .zero, size: size),
                   styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class HistoryPanelController: NSObject, NSWindowDelegate {
    static let size = NSSize(width: 360, height: 440)

    private let store: ClipboardStore
    private let settings: AppSettings
    private let state = PanelState()
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?

    private lazy var panel: HistoryPanel = {
        let panel = HistoryPanel(size: Self.size)
        let view = HistoryView(store: store, state: state,
                               onSelect: { [weak self] in self?.paste($0) },
                               onClose: { [weak self] in self?.hide() })
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: Self.size)
        panel.contentView = hosting
        panel.delegate = self
        return panel
    }()

    private var lastExternalApp: NSRunningApplication?
    private var activationObserver: NSObjectProtocol?

    init(store: ClipboardStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
        super.init()
        lastExternalApp = NSWorkspace.shared.frontmostApplication
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated {
                if let app, app != NSRunningApplication.current {
                    self?.lastExternalApp = app
                }
            }
        }
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
        // An open Settings/Onboarding window makes OptPaste frontmost; target the app used before it.
        if previousApp == NSRunningApplication.current {
            previousApp = lastExternalApp
        }
        state.selectedIndex = 0
        panel.setFrameOrigin(originNearMouse())
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - Positioning

    /// Opens with the top-left corner at the pointer, nudged to stay fully on screen.
    private func originNearMouse() -> NSPoint {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        var origin = NSPoint(x: mouse.x, y: mouse.y - Self.size.height)
        guard let frame = screen?.visibleFrame else { return origin }
        let margin: CGFloat = 8
        origin.x = min(max(origin.x, frame.minX + margin), frame.maxX - Self.size.width - margin)
        origin.y = min(max(origin.y, frame.minY + margin), frame.maxY - Self.size.height - margin)
        return origin
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }

    private func handle(_ event: NSEvent) -> Bool {
        let items = store.displayItems
        let selected = items.indices.contains(state.selectedIndex) ? items[state.selectedIndex] : nil

        switch Int(event.keyCode) {
        case kVK_Escape:
            hide()
        case kVK_DownArrow:
            state.selectedIndex = min(state.selectedIndex + 1, max(items.count - 1, 0))
        case kVK_UpArrow:
            state.selectedIndex = max(state.selectedIndex - 1, 0)
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let selected { paste(selected) }
        case kVK_Delete, kVK_ForwardDelete:
            if let selected {
                store.remove(selected)
                state.selectedIndex = min(state.selectedIndex, max(store.displayItems.count - 1, 0))
            }
        case kVK_ANSI_P:
            if let selected { store.togglePin(selected) }
        default:
            // 1–9 pastes the n-th entry directly.
            guard let digit = event.charactersIgnoringModifiers.flatMap(Int.init),
                  (1...9).contains(digit), items.indices.contains(digit - 1) else { return false }
            paste(items[digit - 1])
        }
        return true
    }

    // MARK: - Paste

    private func paste(_ item: ClipboardItem) {
        store.copyToPasteboard(item)
        hide()

        // With auto-paste off the item just stays on the clipboard. The permission is not
        // checked here: the preflight result can be stale, and without it the post is a no-op.
        guard settings.autoPaste else { return }
        guard let app = previousApp, app != NSRunningApplication.current else {
            Paster.log.info("Colagem ignorada: não há app de destino (o OptPaste estava em primeiro plano)")
            return
        }
        Paster.paste(into: app)
    }
}
