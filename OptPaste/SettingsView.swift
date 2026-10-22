import Carbon.HIToolbox
import Combine
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let controller: AppController

    @State private var canPost = Paster.canPostEvents
    @State private var pasteAccess = PasteAccess.current

    var body: some View {
        @Bindable var settings = controller.settings

        Form {
            Section {
                AboutHeader()
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
            } header: {
                Text("Atalho")
            }

            Section {
                Picker("Guardar até", selection: $settings.historyLimit) {
                    ForEach(AppSettings.historyLimitOptions, id: \.self) { Text("\($0) itens") }
                }
                .onChange(of: settings.historyLimit) { controller.store.trim() }
                Toggle(isOn: $settings.savePasswords) {
                    Text("Guardar senhas")
                    Text("Inclui o que você copia de gerenciadores de senha.")
                }
                LabeledContent("Itens salvos") {
                    Button("Limpar histórico…") { controller.store.clear() }
                }
            } header: {
                Text("Histórico")
            } footer: {
                Text("Itens fixados são mantidos ao limpar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(isOn: $settings.autoPaste) {
                    Text("Colar automaticamente")
                    Text("Envia ⌘V ao escolher um item. Desligado, o item é apenas copiado.")
                }
                .onChange(of: settings.autoPaste) { _, enabled in
                    if enabled && !Paster.canPostEvents { requestPostAccess() }
                }
                if settings.autoPaste {
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
                        Text("Necessária para colar automaticamente.")
                    }
                }
                LabeledContent {
                    if pasteAccess == .allowed {
                        StatusText("Permitido")
                    } else {
                        Button("Abrir Ajustes…") { Paster.openPasteSettings() }
                    }
                } label: {
                    Text("Área de transferência")
                    if pasteAccess != .allowed {
                        Text(pasteAccess == .ask
                             ? "O macOS vai pedir confirmação a cada cópia."
                             : "O acesso está bloqueado.")
                    }
                }
            } header: {
                Text("Colagem")
            }

            Section {
                LaunchAtLoginToggle()
            } header: {
                Text("Geral")
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(permissionTicker) { _ in
            canPost = Paster.canPostEvents
            pasteAccess = .current
        }
    }

    private func requestPostAccess() {
        if !Paster.requestAccess() {
            Paster.openAccessibilitySettings()
        }
    }
}

/// Quiet status like System Settings uses: a small colored dot and secondary text.
private struct StatusText: View {
    let text: String

    init(_ text: String) {
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

/// App icon, name and version, with a manual update check.
private struct AboutHeader: View {
    @State private var updater = UpdateChecker()

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("OptPaste")
                    .font(.title3.weight(.semibold))
                Text("Versão \(UpdateChecker.currentVersion) (\(UpdateChecker.currentBuild))")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                if case let .available(version, url) = updater.state {
                    Button("Baixar versão \(version)…") { NSWorkspace.shared.open(url) }
                } else {
                    Button("Procurar atualizações") {
                        Task { await updater.check() }
                    }
                    .disabled(updater.state == .checking)
                }
                updateStatus
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var updateStatus: some View {
        switch updater.state {
        case .idle:
            EmptyView()
        case .checking:
            Text("Procurando…")
        case .upToDate:
            Text("Você está na versão mais recente.")
        case .available:
            Text("Nova versão disponível.")
        case .failed:
            Text("Não foi possível verificar.")
        }
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
    /// Shown instead of the current shortcut, e.g. when it is already displayed elsewhere.
    var placeholder: String?
    @State private var capture = ShortcutCapture()

    var body: some View {
        Button {
            capture.isRecording ? capture.cancel() : capture.start(current: shortcut) { shortcut = $0 }
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

    func start(current: Shortcut, onCapture: @escaping (Shortcut) -> Void) {
        cancel()
        self.current = current
        isRecording = true
        // Release the current hotkey so pressing it again can be recorded.
        HotKeyManager.shared.unregister()
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
        if !HotKeyManager.shared.register(current) {
            NSSound.beep()
        }
    }
}
