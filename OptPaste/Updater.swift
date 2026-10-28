import AppKit
import Sparkle

/// Automatic updates through Sparkle.
///
/// The feed is the site's `appcast.xml` (`SUFeedURL` in Info.plist); every update is checked against
/// `SUPublicEDKey` before it is installed. Sparkle checks once a day and asks before installing.
@MainActor
@Observable
final class Updater: NSObject, SPUStandardUserDriverDelegate {
    /// `CFBundleShortVersionString` must stay numeric, so the pre-release label lives here.
    /// Set to nil for a stable release. `scripts/release.sh` updates it.
    static let prerelease: String? = nil

    static var currentVersion: String {
        let base = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        return prerelease.map { "\(base)-\($0)" } ?? base
    }

    static var currentBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var isPrerelease: Bool { prerelease != nil }

    private(set) var canCheckForUpdates = false
    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    @ObservationIgnored private var observation: NSKeyValueObservation?

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
        // SPUUpdater lives on the main thread, so its KVO notifications arrive there too.
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            MainActor.assumeIsolated { self?.canCheckForUpdates = updater.canCheckForUpdates }
        }
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            access(keyPath: \.automaticallyChecksForUpdates)
            return controller.updater.automaticallyChecksForUpdates
        }
        set {
            withMutation(keyPath: \.automaticallyChecksForUpdates) {
                controller.updater.automaticallyChecksForUpdates = newValue
            }
        }
    }

    func checkForUpdates() {
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    // MARK: - SPUStandardUserDriverDelegate

    // A menu bar app has no Dock icon to badge, so scheduled updates are shown right away, in front.
    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        Task { @MainActor in NSApp.activate() }
    }
}
