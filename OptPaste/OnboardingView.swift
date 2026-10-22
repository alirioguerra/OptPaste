import SwiftUI

/// First-run screen: the shortcut, a way to change it, and the auto-paste permission.
struct OnboardingView: View {
    let controller: AppController

    @State private var capture = ShortcutCapture()
    @State private var canPost = Paster.canPostEvents
    @State private var didRequestAccess = false

    var body: some View {
        @Bindable var settings = controller.settings

        VStack(spacing: 0) {
            AppIcon()
            Text("Welcome to OptPaste")
                .font(.title.bold())
                .padding(.top, 16)
            Text("Everything you copy, one shortcut away.")
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Group {
                if capture.isRecording {
                    Text("Press the new shortcut")
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

            Button(capture.isRecording ? String(localized: "Cancel") : String(localized: "Change Shortcut")) {
                if capture.isRecording {
                    capture.cancel()
                } else {
                    capture.start(current: settings.shortcut) { settings.shortcut = $0 }
                }
            }
            .buttonStyle(.link)
            .padding(.top, 10)

            VStack(spacing: 8) {
                OptionCard(icon: "doc.on.clipboard", title: String(localized: "Paste automatically"),
                           subtitle: canPost ? String(localized: "Enabled") : String(localized: "Allow in Accessibility")) {
                    if canPost {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                    } else {
                        Button("Allow") {
                            didRequestAccess = true
                            if !Paster.requestAccess() {
                                Paster.openAccessibilitySettings()
                            }
                        }
                    }
                } footer: {
                    if didRequestAccess && !canPost {
                        Button("Already allowed? Reopen OptPaste") { Paster.relaunch() }
                            .buttonStyle(.link)
                            .font(.caption)
                    }
                }

                OptionCard(icon: "key", title: String(localized: "Save passwords"),
                           subtitle: String(localized: "Includes password managers")) {
                    Toggle("Save passwords", isOn: $settings.savePasswords)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
            .padding(.top, 28)

            Button {
                capture.cancel()
                controller.finishOnboarding()
            } label: {
                Text("Get Started").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 24)
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 28)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(permissionTicker) { _ in canPost = Paster.canPostEvents }
        .onDisappear { capture.cancel() }
    }
}

/// Full-width row with an icon, a title/subtitle and a trailing control.
private struct OptionCard<Trailing: View, Footer: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let footer: Footer

    init(icon: String, title: String, subtitle: String,
         @ViewBuilder trailing: () -> Trailing,
         @ViewBuilder footer: () -> Footer = { EmptyView() }) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
        self.footer = footer()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                footer
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 64)
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
