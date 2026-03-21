import AppKit
import Combine
import Foundation

#if canImport(Sparkle)
import Sparkle
#endif

struct ReleaseVersion: Comparable {
    let rawValue: String
    private let components: [Int]

    init(_ rawValue: String) {
        self.rawValue = rawValue
        self.components = Self.parse(rawValue)
    }

    static func < (lhs: ReleaseVersion, rhs: ReleaseVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }

    private static func parse(_ rawValue: String) -> [Int] {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("v") || value.hasPrefix("V") {
            value.removeFirst()
        }
        return value
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }
}

struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: URL
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
    }
}

@MainActor
final class UpdateManager: NSObject {
    private let lastUpdateCheckKey = "ProfileSmithLastUpdateCheckDate"
    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    #if canImport(Sparkle)
    private var sparkleUpdaterController: SPUStandardUpdaterController?
    #endif

    init(settings: AppSettings? = nil) {
        self.settings = settings ?? AppSettings.shared
        super.init()
    }

    func configure() {
        observeSettingsIfNeeded()

        #if canImport(Sparkle)
        guard sparkleUpdaterController == nil, isSparkleConfigured else { return }
        sparkleUpdaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        applySparkleSettings()
        #endif
    }

    func scheduleBackgroundUpdateCheck() {
        switch settings.updateCheckStrategy {
        case .manual:
            return
        case .daily:
            #if canImport(Sparkle)
            if sparkleUpdaterController != nil {
                return
            }
            #endif

            let interval: TimeInterval = 24 * 60 * 60
            if let lastCheckDate = UserDefaults.standard.object(forKey: lastUpdateCheckKey) as? Date,
               Date().timeIntervalSince(lastCheckDate) < interval {
                return
            }
        case .onLaunch:
            #if canImport(Sparkle)
            if let sparkleUpdaterController {
                sparkleUpdaterController.updater.checkForUpdatesInBackground()
                return
            }
            #endif
        }

        Task { [weak self] in
            await self?.checkLatestGitHubRelease(interactive: false)
        }
    }

    func checkForUpdates() {
        #if canImport(Sparkle)
        if let sparkleUpdaterController {
            sparkleUpdaterController.checkForUpdates(nil)
            return
        }
        #endif

        Task {
            await checkLatestGitHubRelease(interactive: true)
        }
    }

    var supportsAutomaticUpdateDownloads: Bool {
        #if canImport(Sparkle)
        guard let updater = sparkleUpdaterController?.updater else { return false }
        return updater.allowsAutomaticUpdates
        #else
        return false
        #endif
    }

    var automaticallyDownloadsUpdates: Bool {
        get {
            #if canImport(Sparkle)
            return sparkleUpdaterController?.updater.automaticallyDownloadsUpdates ?? false
            #else
            return false
            #endif
        }
        set {
            #if canImport(Sparkle)
            sparkleUpdaterController?.updater.automaticallyDownloadsUpdates = newValue
            #endif
        }
    }

    func openGitHubHomepage() {
        guard let url = repositoryURL else { return }
        NSWorkspace.shared.open(url)
    }

    private var repositoryURL: URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "ProfileSmithGitHubURL") as? String else {
            return nil
        }
        return URL(string: rawValue)
    }

    private var latestReleaseAPIURL: URL? {
        guard let rawValue = Bundle.main.object(forInfoDictionaryKey: "ProfileSmithGitHubLatestReleaseAPIURL") as? String else {
            return nil
        }
        return URL(string: rawValue)
    }

    private var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    #if canImport(Sparkle)
    private var isSparkleConfigured: Bool {
        let feedURL = (Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let publicKey = (Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !feedURL.isEmpty && !publicKey.isEmpty
    }

    private func applySparkleSettings() {
        guard let updater = sparkleUpdaterController?.updater else { return }

        switch settings.updateCheckStrategy {
        case .manual:
            updater.automaticallyChecksForUpdates = false
        case .daily:
            updater.updateCheckInterval = 24 * 60 * 60
            updater.automaticallyChecksForUpdates = true
        case .onLaunch:
            updater.automaticallyChecksForUpdates = false
        }
    }
    #endif

    private func observeSettingsIfNeeded() {
        guard cancellables.isEmpty else { return }

        settings.$updateCheckStrategy
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                #if canImport(Sparkle)
                self?.applySparkleSettings()
                #endif
            }
            .store(in: &cancellables)
    }

    private func checkLatestGitHubRelease(interactive: Bool) async {
        guard let latestReleaseAPIURL else {
            if interactive {
                presentFailureAlert(message: L10n.updateNotConfigured)
            }
            return
        }

        do {
            var request = URLRequest(url: latestReleaseAPIURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("ProfileSmith", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                throw URLError(.badServerResponse)
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            UserDefaults.standard.set(Date(), forKey: lastUpdateCheckKey)
            presentReleaseResult(release, interactive: interactive)
        } catch {
            if interactive {
                presentFailureAlert(message: error.localizedDescription)
            }
        }
    }

    private func presentReleaseResult(_ release: GitHubRelease, interactive: Bool) {
        let current = ReleaseVersion(currentVersion)
        let latest = ReleaseVersion(release.tagName)

        guard latest > current else {
            if interactive {
                let alert = NSAlert()
                alert.messageText = L10n.updateUpToDateTitle
                alert.informativeText = L10n.updateUpToDateBody(current: currentVersion, latest: release.tagName)
                alert.runModal()
            }
            return
        }

        let alert = NSAlert()
        alert.messageText = L10n.updateAvailableTitle(release.tagName)
        alert.informativeText = release.body?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? L10n.updateAvailableFallback
        alert.addButton(withTitle: L10n.updateButtonOpenGitHub)
        alert.addButton(withTitle: L10n.cancel)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(release.htmlURL)
        }
    }

    private func presentFailureAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.updateFailureTitle
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.confirm)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
