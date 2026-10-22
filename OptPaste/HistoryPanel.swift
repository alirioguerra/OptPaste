import AppKit
import Carbon.HIToolbox
import Observation
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
    private let state = PanelState()
    private var keyMonitor: Any?
    private var previousApp: NSRunningApplication?
    private var didPromptForAccessibility = false

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

    init(store: ClipboardStore) {
        self.store = store
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    func show() {
        previousApp = NSWorkspace.shared.frontmostApplication
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

        guard Paster.isTrusted else {
            // Without Accessibility we can only put the item on the clipboard.
            if !didPromptForAccessibility {
                didPromptForAccessibility = true
                Paster.requestTrust()
            }
            return
        }
        guard let app = previousApp, app != NSRunningApplication.current else { return }
        app.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Paster.pasteIntoFrontApp()
        }
    }
}
