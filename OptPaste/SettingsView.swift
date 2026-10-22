import Carbon.HIToolbox
import Combine
import ServiceManagement
import SwiftUI

/// The tabs of the Preferences window, shown as toolbar items with icons.
enum PreferencesTab: CaseIterable {
    case general, history, paste, finder, license

    var title: String {
        switch self {
        case .general: "Geral"
        case .history: "Histórico"
        case .paste: "Colagem"
        case .finder: "Finder"
        case .license: "Licença"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .history: "clock.arrow.circlepath"
        case .paste: "doc.on.clipboard"
        case .finder: "folder"
        case .license: "key"
        }
    }

    @MainActor @ViewBuilder
    func pane(_ controller: AppController) -> some View {
        switch self {
        case .general: GeneralPane(controller: controller)
        case .history: HistoryPane(settings: controller.settings, store: controller.store)
        case .paste: PastePane(settings: controller.settings)
        case .finder: FinderPane(settings: controller.settings, finderCut: controller.finderCut)
        case .license: PreferencesPane { LicenseSection(license: controller.license) }
        }
    }
}

/// Toolbar-style tabs; the window resizes to fit each pane.
final class PreferencesTabController: NSTabViewController {
    init(controller: AppController) {
        super.init(nibName: nil, bundle: nil)
        tabStyle = .toolbar
        for tab in PreferencesTab.allCases {
            let hosting = NSHostingController(rootView: tab.pane(controller))
            hosting.sizingOptions = [.preferredContentSize]
            hosting.title = tab.title // shown as the window title while the tab is selected
            let item = NSTabViewItem(viewController: hosting)
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
            addTabViewItem(item)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        guard let window = view.window, let size = tabViewItem?.viewController?.view.fittingSize else { return }
        // Keep the top edge in place, like System Settings panes.
        let content = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        var frame = window.frame
        frame.origin.y += frame.height - content.height
        frame.size = content.size
        window.setFrame(frame, display: true, animate: window.isVisible)
    }
}

/// A grouped form with the Preferences window's width.
private struct PreferencesPane<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .frame(width: 480)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GeneralPane: View {
    let controller: AppController

    var body: some View {
        @Bindable var settings = controller.settings

        PreferencesPane {
            Section {
                AboutHeader(updater: controller.updater)
            }

            Section {
                LabeledContent("Abrir histórico") {
                    HStack(spacing: 8) {
                        if settings.shortcut != .default {
                            Button("Restaurar") {
                                settings.shortcut = .default
                                HotKeyManager.shared.register(.default)
                            }
                            .buttonStyle(.borderless)
                        }
                        ShortcutRecorder(shortcut: $settings.shortcut)
                    }
                }
                LaunchAtLoginToggle()
            }
        }
    }
}

private struct HistoryPane: View {
    @Bindable var settings: AppSettings
    let store: ClipboardStore

    var body: some View {
        PreferencesPane {
            Section {
                Picker("Guardar até", selection: $settings.historyLimit) {
                    ForEach(AppSettings.historyLimitOptions, id: \.self) { Text("\($0) itens") }
                }
                .onChange(of: settings.historyLimit) { store.trim() }
                Toggle(isOn: $settings.savePasswords) {
                    Text("Guardar senhas")
                    Text("Inclui o que você copia de gerenciadores de senha.")
                }
                LabeledContent("Itens salvos") {
                    Button("Limpar histórico…") { store.clear() }
                }
            } footer: {
                Text("Itens fixados são mantidos ao limpar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PastePane: View {
    @Bindable var settings: AppSettings

    @State private var canPost = Paster.canPostEvents
    @State private var pasteAccess = PasteAccess.current

    var body: some View {
        PreferencesPane {
            Section {
                Toggle(isOn: $settings.autoPaste) {
                    Text("Colar automaticamente")
                    Text("Envia ⌘V ao escolher um item. Desligado, o item é apenas copiado.")
                }
                .onChange(of: settings.autoPaste) { _, enabled in
                    if enabled && !Paster.canPostEvents { requestPostAccess() }
                }
                if settings.autoPaste {
                    AccessibilityRow(canPost: canPost, reason: "Necessária para colar automaticamente.")
                }
                LabeledContent {
                    if pasteAccess == .allowed {
                        StatusText("Permitido")
                    } else {
                        Button("Abrir Ajustes do Sistema…") { Paster.openPasteSettings() }
                    }
                } label: {
                    Text("Área de transferência")
                    if pasteAccess != .allowed {
                        Text(pasteAccess == .ask
                             ? "O macOS vai pedir confirmação a cada cópia."
                             : "O acesso está bloqueado.")
                    }
                }
            }
        }
        .onReceive(permissionTicker) { _ in
            canPost = Paster.canPostEvents
            pasteAccess = .current
        }
    }
}

private struct FinderPane: View {
    @Bindable var settings: AppSettings
    let finderCut: FinderCut

    @State private var canPost = Paster.canPostEvents

    var body: some View {
        PreferencesPane {
            Section {
                Toggle(isOn: $settings.finderCut) {
                    Text("Recortar e colar arquivos")
                    Text("\(settings.cutShortcut.displayString) recorta os arquivos selecionados e ⌘V os move para a pasta aberta, em vez de copiar.")
                }
                .onChange(of: settings.finderCut) { _, enabled in
                    if enabled && !Paster.canPostEvents { requestPostAccess() }
                    finderCut.update()
                }
                if settings.finderCut {
                    LabeledContent("Atalho para recortar") {
                        HStack(spacing: 8) {
                            if settings.cutShortcut != .defaultCut {
                                Button("Restaurar") { settings.cutShortcut = .defaultCut }
                                    .buttonStyle(.borderless)
                            }
                            // Only active while Finder is in front, so there is no global hotkey to swap.
                            ShortcutRecorder(shortcut: $settings.cutShortcut, hotKey: nil)
                        }
                    }
                    if !canPost {
                        AccessibilityRow(canPost: canPost, reason: "Necessária para recortar e colar no Finder.")
                    }
                }
            }
        }
        .onReceive(permissionTicker) { _ in canPost = Paster.canPostEvents }
    }
}

/// The Accessibility ("post events") permission, with a way to grant it.
private struct AccessibilityRow: View {
    let canPost: Bool
    let reason: LocalizedStringKey

    var body: some View {
        LabeledContent {
            if canPost {
                StatusText("Permitido")
            } else {
                HStack(spacing: 8) {
                    Button("Reabrir app") { Paster.relaunch() }
                        .buttonStyle(.borderless)
                    Button("Permitir…", action: requestPostAccess)
                }
            }
        } label: {
            Text("Acessibilidade")
            Text(reason)
        }
    }
}

private func requestPostAccess() {
    if !Paster.requestAccess() {
        Paster.openAccessibilitySettings()
    }
}

/// Quiet status like System Settings uses: a small colored dot and secondary text.
private struct StatusText: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(.green)
                .frame(width: 7, height: 7)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

/// Trial status, key activation and purchase.
private struct LicenseSection: View {
    let license: License

    @State private var key = ""
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        Section {
            if case let .licensed(email) = license.status {
                LabeledContent {
                    Button("Desativar neste Mac") {
                        Task {
                            isWorking = true
                            await license.deactivate()
                            isWorking = false
                        }
                    }
                    .disabled(isWorking)
                } label: {
                    Text("Ativada")
                    if let email { Text(email) }
                }
            } else {
                LabeledContent {
                    Button("Comprar…") { NSWorkspace.shared.open(License.checkoutURL) }
                } label: {
                    if case let .trial(daysLeft) = license.status {
                        Text("Teste grátis")
                        Text(daysLeft == 1 ? "Resta 1 dia." : "Restam \(daysLeft) dias.")
                    } else {
                        Text("Teste encerrado")
                        Text("Ative uma licença para voltar a abrir o histórico.")
                    }
                }
                HStack(spacing: 8) {
                    TextField("Chave de licença", text: $key)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(activate)
                    Button("Ativar", action: activate)
                        .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty || isWorking)
                }
            }
        } footer: {
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func activate() {
        guard !isWorking, !key.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                try await license.activate(key: key)
                key = ""
                error = nil
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

/// App icon, name and version, with the update controls.
private struct AboutHeader: View {
    @Bindable var updater: Updater

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("OptPaste")
                        .font(.title3.weight(.semibold))
                    if Updater.isPrerelease {
                        Text("BETA")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .foregroundStyle(.white)
                            .background(.orange, in: Capsule())
                    }
                }
                Text("Versão \(Updater.currentVersion) (\(Updater.currentBuild))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Button("Procurar atualizações…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
                Toggle("Atualizar automaticamente", isOn: $updater.automaticallyChecksForUpdates)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Re-checks permissions every second, since they are changed in System Settings.
let permissionTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

struct LaunchAtLoginToggle: View {
    @State private var isOn = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Abrir ao iniciar sessão", isOn: $isOn)
            .onChange(of: isOn) { _, enabled in
                guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    isOn = SMAppService.mainApp.status == .enabled
                }
            }
    }
}

struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut
    /// The global hotkey to release while recording and re-register afterwards; nil for none.
    var hotKey: HotKeyManager? = .shared
    /// Shown instead of the current shortcut, e.g. when it is already displayed elsewhere.
    var placeholder: String?
    @State private var capture = ShortcutCapture()

    var body: some View {
        Button {
            capture.isRecording ? capture.cancel() : capture.start(current: shortcut, hotKey: hotKey) { shortcut = $0 }
        } label: {
            Text(capture.isRecording ? "Pressione as teclas…" : placeholder ?? shortcut.displayString)
                .frame(minWidth: 110)
        }
        .onDisappear { capture.cancel() }
    }
}

/// Records the next key combination pressed in the app and re-registers the global hotkey.
@Observable
final class ShortcutCapture {
    private(set) var isRecording = false
    @ObservationIgnored private var monitor: Any?
    @ObservationIgnored private var current: Shortcut?
    @ObservationIgnored private var hotKey: HotKeyManager?

    func start(current: Shortcut, hotKey: HotKeyManager? = .shared, onCapture: @escaping (Shortcut) -> Void) {
        cancel()
        self.current = current
        self.hotKey = hotKey
        isRecording = true
        // Release the current hotkey so pressing it again can be recorded.
        hotKey?.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if Int(event.keyCode) == kVK_Escape {
                self.cancel()
                return nil
            }
            guard !event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
                NSSound.beep()
                return nil
            }
            let shortcut = Shortcut(event: event)
            self.current = shortcut
            onCapture(shortcut)
            self.cancel()
            return nil
        }
    }

    /// Stops recording and registers whichever shortcut is current.
    func cancel() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        guard isRecording, let current else { return }
        isRecording = false
        if let hotKey, !hotKey.register(current) {
            NSSound.beep()
        }
    }
}
