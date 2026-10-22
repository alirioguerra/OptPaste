import SwiftUI

struct HistoryView: View {
    let store: ClipboardStore
    let state: PanelState
    let onSelect: (ClipboardItem) -> Void
    let onClose: () -> Void

    var body: some View {
        let items = store.displayItems

        VStack(spacing: 0) {
            header(isEmpty: items.isEmpty)
            if items.isEmpty {
                emptyState
            } else {
                list(items)
            }
            footer
        }
        .frame(width: HistoryPanelController.size.width, height: HistoryPanelController.size.height)
        .glassBackground(cornerRadius: 22)
    }

    private func header(isEmpty: Bool) -> some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(.secondary.opacity(0.5))
                .frame(width: 36, height: 4)
            HStack {
                Text("Área de transferência")
                    .font(.headline)
                Spacer()
                Button("Limpar tudo") { store.clear() }
                    .buttonStyle(.borderless)
                    .disabled(isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(WindowDragArea())
        .help("Arraste para mover")
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
            Text("Nada copiado ainda")
                .font(.headline)
            Text("Copie algo com ⌘C e ele aparecerá aqui.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func list(_ items: [ClipboardItem]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ItemRow(item: item, index: index, isSelected: index == state.selectedIndex, store: store)
                            .id(item.id)
                            .onHover { if $0 { state.selectedIndex = index } }
                            .onTapGesture { onSelect(item) }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.never)
            .onChange(of: state.selectedIndex) { _, index in
                guard items.indices.contains(index) else { return }
                withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(items[index].id) }
            }
        }
    }

    private var footer: some View {
        Text("↩ colar   ↑↓ navegar   P fixar   ⌫ apagar   esc fechar")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}

private struct ItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    let store: ClipboardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 6) {
                if let icon = AppIconCache.icon(for: item.sourceBundleID) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                }
                Text(item.date.formatted(.relative(presentation: .named)))
                if item.isPinned {
                    Image(systemName: "pin.fill")
                }
                Spacer()
                if isSelected {
                    actions
                } else if index < 9 {
                    Text("\(index + 1)")
                        .monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.28)) : AnyShapeStyle(Color.primary.opacity(0.06)))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text:
            Text((item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
                .font(.system(size: 13))
                .lineLimit(3)
        case .image:
            if let image = store.thumbnail(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 90, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Label("Imagem indisponível", systemImage: "photo")
            }
        case .files:
            let urls = item.fileURLs ?? []
            HStack(spacing: 8) {
                if let first = urls.first {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: first.path))
                        .resizable()
                        .frame(width: 28, height: 28)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.menuTitle)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if let first = urls.first {
                        Text(first.deletingLastPathComponent().path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button { store.togglePin(item) } label: {
                Image(systemName: item.isPinned ? "pin.slash" : "pin")
            }
            .help(item.isPinned ? "Desafixar" : "Fixar")
            Button { store.remove(item) } label: {
                Image(systemName: "trash")
            }
            .help("Apagar")
        }
        .buttonStyle(.borderless)
    }
}

private enum AppIconCache {
    private static var icons: [String: NSImage] = [:]

    static func icon(for bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let icon = icons[bundleID] { return icon }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundleID] = icon
        return icon
    }
}

/// Drags the hosting window from wherever this view is placed.
private struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Glass

private extension View {
    /// Liquid Glass on macOS 26+, falling back to the classic translucent material.
    @ViewBuilder
    func glassBackground(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(VisualEffectBackground().clipShape(shape))
                .overlay(shape.strokeBorder(Color.primary.opacity(0.1)))
        }
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
