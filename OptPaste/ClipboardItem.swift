import Foundation

struct ClipboardItem: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case text, image, files
        /// App-specific content (e.g. Figma layers), restored from the saved payload.
        case other
    }

    var id = UUID()
    var kind: Kind
    var text: String?
    /// Label for `.other` entries.
    var title: String?
    var rtf: Data?
    var fileURLs: [URL]?
    /// Identifies identical content so re-copying moves the entry instead of duplicating it.
    var signature: String
    var date = Date()
    var isPinned = false
    var sourceBundleID: String?

    var menuTitle: String {
        switch kind {
        case .text:
            let line = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines).first ?? ""
            return line.count > 40 ? String(line.prefix(40)) + "…" : line
        case .image:
            return "Imagem"
        case .files:
            let names = (fileURLs ?? []).map(\.lastPathComponent)
            return names.count == 1 ? names[0] : "\(names.count) arquivos"
        case .other:
            return title ?? "Conteúdo copiado"
        }
    }
}
