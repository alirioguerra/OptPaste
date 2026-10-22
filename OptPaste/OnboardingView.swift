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
        .frame(width: 540, height: 540)
    }

    private func move(by offset: Int) {
        guard let next = Step(rawValue: step.rawValue + offset) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { step = next }
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.clipboard.fill")
                .font(.system(size: 46))
                .foregroundStyle(Color.accentColor)
            Text("Tudo o que você copia, sempre à mão")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text("O OptPaste guarda o que você copia para que você encontre e cole de novo quando precisar.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Feature(icon: "menubar.rectangle", title: "Sempre por perto",
                        text: "Funciona em segundo plano e fica na barra de menus.")
                Feature(icon: "keyboard", title: "Acesso rápido",
                        text: "Navegue com as setas e escolha um item com Return ou com as teclas de 1 a 9.")
                Feature(icon: "pin", title: "Seus favoritos",
                        text: "Fixe os itens que você usa com frequência.")
                Feature(icon: "key", title: "Senhas fora do histórico",
                        text: "Senhas copiadas de gerenciadores compatíveis não são guardadas.")
            }
            .padding(.top, 6)
        }
    }
}

private struct Feature: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ShortcutStep: View {
    @Bindable var settings: AppSettings

    private static let suggestions: [(Shortcut, String)] = [
        (.default, "Recomendado. Fácil de lembrar e rápido de usar."),
        (Shortcut(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(controlKey | optionKey | cmdKey), keyLabel: "V"),
         "Alternativa caso o ⌥V já seja usado por outro app."),
        (Shortcut(keyCode: UInt32(kVK_ANSI_V), carbonModifiers: UInt32(controlKey | optionKey | shiftKey | cmdKey), keyLabel: "V"),
         "A opção com menor chance de conflito."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Escolha seu atalho")
                .font(.title.bold())
            Text("Defina as teclas que abrem o histórico. Use uma sugestão ou grave outra combinação. Você pode mudar isso a qualquer momento nos Ajustes.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(Self.suggestions, id: \.0.displayString) { shortcut, detail in
                    Button { choose(shortcut) } label: {
                        HStack {
                            Text(shortcut.displayString)
                                .font(.title3.monospaced().weight(.semibold))
                                .frame(width: 84, alignment: .leading)
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
                Text("Personalizar atalho")
                Spacer()
                ShortcutRecorder(shortcut: $settings.shortcut,
                                 placeholder: isSuggested ? "Grave uma combinação de teclas" : nil)
            }
        }
    }

    private var isSuggested: Bool {
        Self.suggestions.contains { $0.0 == settings.shortcut }
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
