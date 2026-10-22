import Carbon.HIToolbox
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let controller: AppController

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var isTrusted = Paster.isTrusted
    @State private var pasteAccess = PasteAccess.current

    var body: some View {
        @Bindable var settings = controller.settings

        Form {
            Section("Atalho") {
                LabeledContent("Abrir histórico") {
                    ShortcutRecorder(shortcut: $settings.shortcut)
                }
                Button("Restaurar padrão (⌥V)") {
                    settings.shortcut = .default
                    HotKeyManager.shared.register(.default)
                }
                .disabled(settings.shortcut == .default)
            }

            Section("Histórico") {
                Picker("Guardar até", selection: $settings.historyLimit) {
                    ForEach(AppSettings.historyLimitOptions, id: \.self) { Text("\($0) itens") }
                }
                .onChange(of: settings.historyLimit) { controller.store.trim() }
                Button("Limpar histórico", role: .destructive) { controller.store.clear() }
            }

            Section("Geral") {
                Toggle("Abrir ao iniciar sessão", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("Permissões") {
                LabeledContent("Acessibilidade") {
                    if isTrusted {
                        Label("Concedida", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("Conceder…") {
                            Paster.requestTrust()
                            Paster.openAccessibilitySettings()
                        }
                    }
                }
                if !isTrusted {
                    Text("Necessária para colar automaticamente. Sem ela, o item escolhido só é copiado.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let message = pasteAccess.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isTrusted = Paster.isTrusted
            pasteAccess = .current
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// macOS 15.4+ lets users decide whether apps may read the pasteboard without asking.
private enum PasteAccess {
    case fine, ask, denied

    static var current: PasteAccess {
        guard #available(macOS 15.4, *) else { return .fine }
        switch NSPasteboard.general.accessBehavior {
        case .ask: return .ask
        case .alwaysDeny: return .denied
        default: return .fine
        }
    }

    var message: String? {
        switch self {
        case .fine: nil
        case .ask: "O macOS vai pedir confirmação a cada cópia. Em Ajustes do Sistema › Privacidade e Segurança › Colar, permita o OptPaste."
        case .denied: "O acesso à área de transferência está negado. Permita o OptPaste em Ajustes do Sistema › Privacidade e Segurança › Colar."
        }
    }
}

struct ShortcutRecorder: View {
    @Binding var shortcut: Shortcut
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stop() : start()
        } label: {
            Text(isRecording ? "Pressione o atalho…" : shortcut.displayString)
                .frame(minWidth: 110)
        }
        .onDisappear { stop() }
    }

    private func start() {
        isRecording = true
        // Release the current hotkey so pressing it again can be recorded.
        HotKeyManager.shared.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stop()
                return nil
            }
            let modifiers = event.modifierFlags.intersection([.command, .option, .control])
            guard !modifiers.isEmpty else {
                NSSound.beep()
                return nil
            }
            shortcut = Shortcut(event: event)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        guard isRecording else { return }
        isRecording = false
        if !HotKeyManager.shared.register(shortcut) {
            NSSound.beep()
        }
    }
}
