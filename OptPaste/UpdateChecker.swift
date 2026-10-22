import AppKit
import OSLog

/// Compares the running version with the newest GitHub release of the project.
///
/// Releases must be tagged with a semantic version, optionally prefixed with "v"
/// (e.g. `v1.0.0-beta.2`, `v1.0.0`). Pre-releases are included while the app is a pre-release.
@MainActor
@Observable
final class UpdateChecker {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL)
        case failed
    }

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "OptPaste", category: "update")
    private static let releasesURL = URL(string: "https://api.github.com/repos/alirioguerra/optpaste-site/releases?per_page=20")!

    /// `CFBundleShortVersionString` must stay numeric, so the pre-release label lives here.
    /// Set to nil for a stable release.
    static let prerelease: String? = "beta.1"

    static var currentVersion: String {
        let base = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        return prerelease.map { "\(base)-\($0)" } ?? base
    }

    static var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var isPrerelease: Bool { prerelease != nil }

    private(set) var state = State.idle

    func check() async {
        guard state != .checking else { return }
        state = .checking
        do {
            var request = URLRequest(url: Self.releasesURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let current = SemanticVersion(Self.currentVersion)
            let newest = try JSONDecoder().decode([Release].self, from: data)
                .filter { !$0.draft && (Self.isPrerelease || !$0.prerelease) }
                .map { (version: SemanticVersion($0.tagName), release: $0) }
                .max { $0.version < $1.version }
            if let newest, current < newest.version {
                state = .available(version: newest.version.description, url: newest.release.htmlURL)
            } else {
                state = .upToDate
            }
        } catch {
            Self.log.error("Falha ao procurar atualizações: \(error.localizedDescription, privacy: .public)")
            state = .failed
        }
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL
        let draft: Bool
        let prerelease: Bool

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case draft
            case prerelease
        }
    }
}

/// Just enough of SemVer to order `1.0.0-beta.1` < `1.0.0-beta.2` < `1.0.0` < `1.0.1`.
struct SemanticVersion: Comparable, CustomStringConvertible {
    let core: [Int]
    let prerelease: [String]

    init(_ string: String) {
        let trimmed = string.trimmingPrefix("v")
        let parts = trimmed.split(separator: "-", maxSplits: 1)
        core = (parts.first ?? "").split(separator: ".").map { Int($0) ?? 0 }
        prerelease = parts.count > 1 ? parts[1].split(separator: ".").map(String.init) : []
    }

    var description: String {
        let base = core.map(String.init).joined(separator: ".")
        return prerelease.isEmpty ? base : base + "-" + prerelease.joined(separator: ".")
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        for index in 0..<max(lhs.core.count, rhs.core.count) {
            let a = index < lhs.core.count ? lhs.core[index] : 0
            let b = index < rhs.core.count ? rhs.core[index] : 0
            if a != b { return a < b }
        }
        // A release ranks above any of its pre-releases.
        switch (lhs.prerelease.isEmpty, rhs.prerelease.isEmpty) {
        case (true, true), (true, false): return false
        case (false, true): return true
        case (false, false): break
        }
        for (a, b) in zip(lhs.prerelease, rhs.prerelease) where a != b {
            switch (Int(a), Int(b)) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a < b
            }
        }
        return lhs.prerelease.count < rhs.prerelease.count
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}
