import AppKit
import OSLog

/// Compares the running version with the latest GitHub release of the project.
///
/// Releases must be tagged with the version, optionally prefixed with "v" (e.g. `v1.2`).
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
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/alirioguerra/OptPaste/releases/latest")!

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    static var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private(set) var state = State.idle

    func check() async {
        guard state != .checking else { return }
        state = .checking
        do {
            var request = URLRequest(url: Self.latestReleaseURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let latest = release.tagName.trimmingPrefix("v")
            if Self.isVersion(String(latest), newerThan: Self.currentVersion) {
                state = .available(version: String(latest), url: release.htmlURL)
            } else {
                state = .upToDate
            }
        } catch {
            Self.log.error("Falha ao procurar atualizações: \(error.localizedDescription, privacy: .public)")
            state = .failed
        }
    }

    /// Numeric, component-wise comparison, so "1.10" is newer than "1.9".
    private static func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        let lhs = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    private struct Release: Decodable {
        let tagName: String
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }
}
