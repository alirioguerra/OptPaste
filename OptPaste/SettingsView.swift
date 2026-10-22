import Carbon.HIToolbox
import Combine
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let controller: AppController

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
                Toggle("Guardar senhas", isOn: $settings.savePasswords)
                Button("Limpar histórico", role: .destructive) { controller.store.clear() }
            }

            Section("Geral") {
                LaunchAtLoginToggle()
            }

            Section("Permissões") {
                AutoPasteRow(autoPaste: $settings.autoPaste)
                PasteAccessRow()
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 520)
    }
}

// MARK: - Shared rows

/// Re-checks permissions every second, since they are changed in System Settings.
let permissionTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

struct AutoPasteRow: View {
    @Binding var autoPaste: Bool
    @State private var canPost = Paster.canPostEvents

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Colar automaticamente", isOn: $autoPaste)
                .onChange(of: autoPaste) { _, enabled in
                    if enabled && !Paster.canPostEvents { requestAccess() }
                }
            Text("Ao escolher um item, o OptPaste envia ⌘V por você. Desligado, o item só é copiado e você cola com ⌘V.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if autoPaste {
                HStack {
                    if canPost {
                        Label("Permissão concedida", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Permissão pendente em Acessibilidade", systemImage: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Permitir…", action: requestAccess)
                    }
                }
                .font(.callout)
                if !canPost {
                    Button("Já permitiu? Reabrir o OptPaste") { Paster.relaunch() }
                        .buttonStyle(.link)
                        .font(.caption)
                }
            }
        }
        .onReceive(permissionTicker) { _ in canPost = Paster.canPostEvents }
    }

    private func requestAccess() {
        if !Paster.requestAccess() {
            Paster.openAccessibilitySettings()
        }
    }
}

struct PasteAccessRow: View {
    @State private var access = PasteAccess.current

    var body: some View {
        Group {
            if let message = access.message {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Acesso à área de transferência", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Abrir Privacidade › Colar…") { Paster.openPasteSettings() }
                }
            } else {
                Label("Acesso à área de transferência liberado", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .onReceive(permissionTicker) { _ in access = .current }
    }
}

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
