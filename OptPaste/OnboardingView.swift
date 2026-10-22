import Carbon.HIToolbox
import SwiftUI

/// First-run walkthrough: what the app does, which shortcut to use, and permissions.
struct OnboardingView: View {
    let controller: AppController

    private enum Step: Int, CaseIterable {
        case welcome, shortcut, permissions
    }

    @State private var step = Step.welcome

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: WelcomeStep()
                case .shortcut: ShortcutStep(settings: controller.settings)
                case .permissions: PermissionsStep(settings: controller.settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 36)
            .padding(.top, 28)

            HStack {
                HStack(spacing: 6) {
                    ForEach(Step.allCases, id: \.self) { item in
                        Circle()
                            .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                    }
                }
                Spacer()
                if step != .welcome {
                    Button("Voltar") { move(by: -1) }
                }
                if step == .permissions {
                    Button("Começar") { controller.finishOnboarding() }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Continuar") { move(by: 1) }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
            .padding(20)
        }
        .frame(width: 520, height: 460)
    }

    private func move(by offset: Int) {
        guard let next = Step(rawValue: step.rawValue + offset) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { step = next }
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "list.clipboard.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color.accentColor)
            Text("Bem-vindo ao OptPaste")
                .font(.largeTitle.bold())
            Text("Tudo o que você copia com ⌘C fica guardado. Com um atalho, o histórico abre junto do cursor e você escolhe o que colar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Feature(icon: "menubar.rectangle", text: "Roda em segundo plano, com um ícone na barra de menus.")
                Feature(icon: "keyboard", text: "Navegue com ↑↓, cole com ↩ ou com os números de 1 a 9.")
                Feature(icon: "pin", text: "Fixe os itens que você usa sempre.")
                Feature(icon: "lock", text: "Senhas copiadas de gerenciadores de senha não são salvas.")
            }
            .padding(.top, 6)
        }
    }
}

private struct Feature: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(Color.accentColor)
            Text(text)
        }
    }
}

private struct ShortcutStep: View {
    @Bindable var settings: AppSettings

    private static let suggestions: [(Shortcut, String)] = [
        (.default, "Recomendado, parecido com o ⊞V do Windows"),
        (Shortcut(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(controlKey | cmdKey), keyLabel: "V"),
         "Útil se você digita “√” com ⌥V"),
        (Shortcut(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(controlKey | optionKey), keyLabel: "V"),
         "Difícil de apertar sem querer"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Qual atalho abre o histórico?")
                .font(.title.bold())
            Text("Escolha uma sugestão ou grave a combinação que preferir. Dá para mudar depois nos Ajustes.")
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                ForEach(Self.suggestions, id: \.0.displayString) { shortcut, detail in
                    Button { choose(shortcut) } label: {
                        HStack {
                            Text(shortcut.displayString)
                                .font(.title3.monospaced().weight(.semibold))
                                .frame(width: 70, alignment: .leading)
                            Text(detail)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if settings.shortcut == shortcut {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(settings.shortcut == shortcut ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Outro atalho:")
                ShortcutRecorder(shortcut: $settings.shortcut)
            }
        }
    }

    private func choose(_ shortcut: Shortcut) {
        settings.shortcut = shortcut
        if !HotKeyManager.shared.register(shortcut) {
            NSSound.beep()
        }
    }
}

private struct PermissionsStep: View {
    @Bindable var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissões")
                .font(.title.bold())
            Text("O OptPaste não pede acesso total ao Mac. Só precisa de uma permissão, e ela é opcional.")
                .foregroundStyle(.secondary)

            GroupBox {
                AutoPasteRow(autoPaste: $settings.autoPaste)
                    .padding(6)
            }
            GroupBox {
                PasteAccessRow()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }
            GroupBox {
                LaunchAtLoginToggle()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
            }
        }
    }
}
