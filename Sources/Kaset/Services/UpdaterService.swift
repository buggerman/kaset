import Foundation
import Sparkle

// MARK: - UpdateChannel

enum UpdateChannel: String, CaseIterable {
    case stable
    case nightly

    var displayName: String {
        switch self {
        case .stable: String(localized: "Stable")
        case .nightly: String(localized: "Nightly")
        }
    }

    var feedURL: URL? {
        switch self {
        case .stable:
            nil // uses SUFeedURL from Info.plist
        case .nightly:
            URL(string: "https://raw.githubusercontent.com/buggerman/kaset/main/appcast-nightly.xml")
        }
    }
}

// MARK: - UpdaterDelegate

private final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    var channel: UpdateChannel = .stable

    func feedURLString(for _: SPUUpdater) -> String? {
        self.channel.feedURL?.absoluteString
    }
}

// MARK: - UpdaterService

/// Manages application updates via Sparkle framework.
@available(macOS 26.0, *)
@MainActor
@Observable
final class UpdaterService {
    private let updaterController: SPUStandardUpdaterController
    private let delegate = UpdaterDelegate()

    private static let channelKey = "updateChannel"

    var automaticChecksEnabled: Bool {
        get { self.updaterController.updater.automaticallyChecksForUpdates }
        set { self.updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    var canCheckForUpdates: Bool {
        self.updaterController.updater.canCheckForUpdates
    }

    var lastUpdateCheckDate: Date? {
        self.updaterController.updater.lastUpdateCheckDate
    }

    var updateChannel: UpdateChannel {
        get { self.delegate.channel }
        set {
            self.delegate.channel = newValue
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.channelKey)
            DiagnosticsLogger.updater.info("Update channel changed to \(newValue.rawValue)")
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.channelKey) ?? ""
        self.delegate.channel = UpdateChannel(rawValue: stored) ?? .stable

        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self.delegate,
            userDriverDelegate: nil
        )

        DiagnosticsLogger.updater.info("UpdaterService initialized (channel: \(self.delegate.channel.rawValue))")
    }

    func checkForUpdates() {
        DiagnosticsLogger.updater.info("Manually checking for updates")
        self.updaterController.checkForUpdates(nil)
    }
}
