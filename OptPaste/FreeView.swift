import SwiftUI

enum Support {
    static let coffeeURL = URL(string: "https://buymeacoffee.com/alirioguerra")!
    static let repoURL = URL(string: "https://github.com/alirioguerra/OptPaste")!
}

/// Shown on launch: OptPaste is free forever, with an optional way to support it.
struct FreeView: View {
    let controller: AppController

    var body: some View {
        @Bindable var settings = controller.settings

        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
            Text("OptPaste is free forever")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            Text("No trial, no license, no ads. If OptPaste helps you and you’d like to support it, you can buy me a coffee.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Button {
                NSWorkspace.shared.open(Support.coffeeURL)
            } label: {
                Label("Buy Me a Coffee", systemImage: "cup.and.saucer.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 24)

            Link("buymeacoffee.com/alirioguerra", destination: Support.coffeeURL)
                .font(.callout)
                .padding(.top, 10)
            Link("Open source on GitHub", destination: Support.repoURL)
                .font(.callout)
                .padding(.top, 4)

            Button {
                controller.closeFreeNotice()
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.top, 20)

            Toggle("Show on launch", isOn: $settings.showFreeNotice)
                .toggleStyle(.checkbox)
                .font(.callout)
                .padding(.top, 14)
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The Support tab in Preferences.
struct SupportSection: View {
    var body: some View {
        Section {
            LabeledContent {
                Button("Buy Me a Coffee…") { NSWorkspace.shared.open(Support.coffeeURL) }
            } label: {
                Text("OptPaste is free forever")
                Text("If it helps you, you can support it with a coffee.")
            }
            LabeledContent {
                Button("View on GitHub…") { NSWorkspace.shared.open(Support.repoURL) }
            } label: {
                Text("Open source")
                Text("Anyone can check what OptPaste does with what you copy.")
            }
        }
    }
}
