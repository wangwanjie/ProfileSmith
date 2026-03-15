import AppKit
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
    static let shared = UpdateManager()

    #if canImport(Sparkle)
    private var sparkleUpdaterController: SPUStandardUpdaterController?
    #endif

    func configure() {
        #if canImport(Sparkle)
        guard sparkleUpdaterController == nil, isSparkleConfigured else { return }
        sparkleUpdaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        #endif
    }

    func scheduleBackgroundUpdateCheck() {
        #if canImport(Sparkle)
        sparkleUpdaterController?.updater.checkForUpdatesInBackground()
        #endif
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
    #endif

    private func checkLatestGitHubRelease(interactive: Bool) async {
        guard let latestReleaseAPIURL else { return }

        do {
            var request = URLRequest(url: latestReleaseAPIURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("ProfileSmith", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                throw URLError(.badServerResponse)
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            presentReleaseResult(release, interactive: interactive)
        } catch {
            if interactive {
                let alert = NSAlert()
                alert.messageText = "检查更新失败"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    private func presentReleaseResult(_ release: GitHubRelease, interactive: Bool) {
        let current = ReleaseVersion(currentVersion)
        let latest = ReleaseVersion(release.tagName)

        guard latest > current else {
            if interactive {
                let alert = NSAlert()
                alert.messageText = "当前已是最新版本"
                alert.informativeText = "当前版本 \(currentVersion)，GitHub 最新版本 \(release.tagName)。"
                alert.runModal()
            }
            return
        }

        let alert = NSAlert()
        alert.messageText = "发现新版本 \(release.tagName)"
        alert.informativeText = release.body?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "是否前往 GitHub 查看并下载？"
        alert.addButton(withTitle: "打开 GitHub")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(release.htmlURL)
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
