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
    /// Copied from a password manager (marked concealed). Optional so older history still decodes.
    var isConcealed: Bool?

    var isPassword: Bool { isConcealed == true }

    /// Shows only the first characters. The bullet count is fixed so the length isn't revealed.
    var maskedText: String {
        let password = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = password.count >= 8 ? 3 : 1
        return String(password.prefix(visible)) + String(repeating: "•", count: 8)
    }

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
