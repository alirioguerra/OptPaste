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
final class AppController {
    static let shared = AppController()

    let settings = AppSettings()
    let store: ClipboardStore
    private(set) lazy var panel = HistoryPanelController(store: store)
    private var settingsWindow: NSWindow?

    private init() {
        store = ClipboardStore(settings: settings)
    }

    func start() {
        store.startMonitoring()
        HotKeyManager.shared.onPress = { [weak self] in self?.panel.toggle() }
        HotKeyManager.shared.register(settings.shortcut)
    }

    func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(controller: self)))
            window.title = "Ajustes do OptPaste"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
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
        Divider()
        Button("Sair do OptPaste") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
