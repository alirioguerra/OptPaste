import SwiftUI

/// First-run screen: the shortcut, a way to change it, and the auto-paste permission.
struct OnboardingView: View {
    let controller: AppController

    @State private var capture = ShortcutCapture()
    @State private var canPost = Paster.canPostEvents
    @State private var didRequestAccess = false

    var body: some View {
        let settings = controller.settings

        VStack(spacing: 0) {
            AppIcon()
            Text("Bem-vindo ao OptPaste")
                .font(.title.bold())
                .padding(.top, 16)
            Text("Tudo o que você copia, a um atalho de distância.")
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Group {
                if capture.isRecording {
                    Text("Pressione o novo atalho")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                .foregroundStyle(Color.accentColor)
                        )
                } else {
                    KeycapRow(shortcut: settings.shortcut)
                }
            }
            .frame(height: 64)
            .padding(.top, 32)

            Button(capture.isRecording ? "Cancelar" : "Alterar atalho") {
                if capture.isRecording {
                    capture.cancel()
                } else {
                    capture.start(current: settings.shortcut) { settings.shortcut = $0 }
                }
            }
            .buttonStyle(.link)
            .padding(.top, 10)

            permissionCard
                .padding(.top, 32)

            Spacer(minLength: 24)

            Button {
                capture.cancel()
                controller.finishOnboarding()
            } label: {
                Text("Começar").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 420, height: 540)
        .onReceive(permissionTicker) { _ in canPost = Paster.canPostEvents }
        .onDisappear { capture.cancel() }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Colar automaticamente")
                        .fontWeight(.semibold)
                    Text(canPost ? "Ativado" : "Permita em Acessibilidade")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if canPost {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else {
                    Button("Permitir") {
                        didRequestAccess = true
                        if !Paster.requestAccess() {
                            Paster.openAccessibilitySettings()
                        }
                    }
                }
            }
            if didRequestAccess && !canPost {
                Button("Já permitiu? Reabrir o OptPaste") { Paster.relaunch() }
                    .buttonStyle(.link)
                    .font(.caption)
                    .padding(.leading, 40)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

private struct AppIcon: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(LinearGradient(colors: [Color.accentColor.opacity(0.75), Color.accentColor],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "list.clipboard.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(.white)
            )
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }
}

/// The shortcut drawn as Mac keyboard keys.
struct KeycapRow: View {
    let shortcut: Shortcut

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(shortcut.keycaps.enumerated()), id: \.offset) { _, key in
                Keycap(symbol: key.symbol, name: key.name)
            }
        }
    }
}

private struct Keycap: View {
    let symbol: String
    let name: String?

    var body: some View {
        ZStack {
            if let name {
                Text(symbol)
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                Text(name)
                    .font(.system(size: 10))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            } else {
                Text(symbol)
                    .font(.system(size: 22, weight: .medium))
            }
        }
        .padding(8)
        .frame(width: name == nil ? 58 : 72, height: 58)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.3), radius: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12))
        )
    }
}
