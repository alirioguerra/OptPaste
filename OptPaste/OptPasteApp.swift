import SwiftUI

@main struct OptPasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(controller: .shared)
        } label: {
            Image(systemName: "list.clipboard")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppController.shared.start()
    }
}

/// Owns the long-lived pieces of the app: settings, history, hotkey and windows.
final class AppController: NSObject, NSWindowDelegate {
    static let shared = AppController()

    let settings = AppSettings()
    let store: ClipboardStore
    private(set) lazy var panel = HistoryPanelController(store: store, settings: settings)
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?

    private override init() {
        store = ClipboardStore(settings: settings)
        super.init()
    }

    func start() {
        store.startMonitoring()
        let panel = panel // created now so it starts tracking the active app right away
        HotKeyManager.shared.onPress = { panel.toggle() }
        HotKeyManager.shared.register(settings.shortcut)
        if !settings.didCompleteOnboarding {
            openOnboarding()
        }
    }

    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = makeWindow(title: "Ajustes do OptPaste", rootView: SettingsView(controller: self))
        }
        present(settingsWindow)
    }

    func openOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = makeWindow(title: "Bem-vindo ao OptPaste", rootView: OnboardingView(controller: self))
        }
        present(onboardingWindow)
    }

    func finishOnboarding() {
        settings.didCompleteOnboarding = true
        onboardingWindow?.close()
    }

    // MARK: - Windows

    private func makeWindow(title: String, rootView: some View) -> NSWindow {
        let hosting = NSHostingController(rootView: rootView)
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    /// A menu-bar-only (accessory) app can't reliably bring its windows to the front,
    /// so it becomes a regular app while one of its windows is open.
    private func present(_ window: NSWindow?) {
        guard let window else { return }
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        let closing = notification.object as? NSWindow
        let stillOpen = [settingsWindow, onboardingWindow].contains { $0 !== closing && $0?.isVisible == true }
        if !stillOpen {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

struct MenuBarContent: View {
    let controller: AppController

    var body: some View {
        Button("Mostrar histórico (\(controller.settings.shortcut.displayString))") {
            // Let the menu finish closing before the panel takes key focus.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { controller.panel.show() }
        }

        let recent = controller.store.displayItems.prefix(5)
        if !recent.isEmpty {
            Divider()
            Text("Recentes")
            ForEach(recent) { item in
                Button(item.menuTitle) { controller.store.copyToPasteboard(item) }
            }
        }

        Divider()
        Button("Limpar histórico") { controller.store.clear() }
        Button("Ajustes…") { controller.openSettings() }
            .keyboardShortcut(",")
        Button("Boas-vindas e permissões…") { controller.openOnboarding() }
        Divider()
        Button("Sair do OptPaste") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
