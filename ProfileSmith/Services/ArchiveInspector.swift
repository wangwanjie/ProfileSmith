import Foundation

final class PreviewInspection {
    let sourceURL: URL
    let title: String
    let parsedProfile: ParsedProfile?
    let infoPlist: [String: Any]?
    let quickLookHTML: String
    private let temporaryDirectory: URL?

    init(
        sourceURL: URL,
        title: String,
        parsedProfile: ParsedProfile?,
        infoPlist: [String: Any]?,
        quickLookHTML: String,
        temporaryDirectory: URL? = nil
    ) {
        self.sourceURL = sourceURL
        self.title = title
        self.parsedProfile = parsedProfile
        self.infoPlist = infoPlist
        self.quickLookHTML = quickLookHTML
        self.temporaryDirectory = temporaryDirectory
    }

    deinit {
        guard let temporaryDirectory else { return }
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }
}

final class ArchiveInspector {
    private let parser: MobileProvisionParser

    init(parser: MobileProvisionParser) {
        self.parser = parser
    }

    func inspect(url: URL) throws -> PreviewInspection {
        switch url.pathExtension.lowercased() {
        case "mobileprovision", "provisionprofile":
            let location = ScanLocation(kind: .custom, url: url.deletingLastPathComponent(), displayName: "Imported")
            let parsed = try parser.parseProfile(at: url, sourceLocation: location)
            return PreviewInspection(
                sourceURL: url,
                title: parsed.record.displayName,
                parsedProfile: parsed,
                infoPlist: nil,
                quickLookHTML: Self.renderHTML(title: parsed.record.displayName, profile: parsed, infoPlist: nil)
            )
        case "ipa":
            return try inspectIPA(url: url)
        case "xcarchive":
            return try inspectArchiveBundle(url: url)
        case "app", "appex":
            return try inspectApplicationBundle(url: url)
        default:
            throw ParserError.unsupportedFile(url)
        }
    }

    func makeInspection(for parsedProfile: ParsedProfile, sourceURL: URL) -> PreviewInspection {
        PreviewInspection(
            sourceURL: sourceURL,
            title: parsedProfile.record.displayName,
            parsedProfile: parsedProfile,
            infoPlist: nil,
            quickLookHTML: Self.renderHTML(title: parsedProfile.record.displayName, profile: parsedProfile, infoPlist: nil)
        )
    }

    private func inspectIPA(url: URL) throws -> PreviewInspection {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ProfileSmith-Preview-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        try runProcess(launchPath: "/usr/bin/ditto", arguments: ["-x", "-k", url.path, temporaryDirectory.path])

        let payloadDirectory = temporaryDirectory.appendingPathComponent("Payload", isDirectory: true)
        let applicationURL = try findApplicationBundle(in: payloadDirectory)
        let inspection = try inspectApplicationBundle(url: applicationURL)
        return PreviewInspection(
            sourceURL: url,
            title: inspection.title,
            parsedProfile: inspection.parsedProfile,
            infoPlist: inspection.infoPlist,
            quickLookHTML: inspection.quickLookHTML,
            temporaryDirectory: temporaryDirectory
        )
    }

    private func inspectArchiveBundle(url: URL) throws -> PreviewInspection {
        let applicationsDirectory = url
            .appendingPathComponent("Products", isDirectory: true)
            .appendingPathComponent("Applications", isDirectory: true)
        let applicationURL = try findApplicationBundle(in: applicationsDirectory)
        let inspection = try inspectApplicationBundle(url: applicationURL)
        return PreviewInspection(
            sourceURL: url,
            title: inspection.title,
            parsedProfile: inspection.parsedProfile,
            infoPlist: inspection.infoPlist,
            quickLookHTML: inspection.quickLookHTML
        )
    }

    private func inspectApplicationBundle(url: URL) throws -> PreviewInspection {
        let infoPlistURL = url.appendingPathComponent("Info.plist", isDirectory: false)
        let embeddedProfileURL = url.appendingPathComponent("embedded.mobileprovision", isDirectory: false)

        let infoPlist = NSDictionary(contentsOf: infoPlistURL) as? [String: Any]
        let title = (infoPlist?["CFBundleDisplayName"] as? String)
            ?? (infoPlist?["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent

        let parsedProfile: ParsedProfile?
        if FileManager.default.fileExists(atPath: embeddedProfileURL.path) {
            let location = ScanLocation(kind: .custom, url: url.deletingLastPathComponent(), displayName: "Embedded")
            parsedProfile = try parser.parseProfile(at: embeddedProfileURL, sourceLocation: location)
        } else {
            parsedProfile = nil
        }

        return PreviewInspection(
            sourceURL: url,
            title: title,
            parsedProfile: parsedProfile,
            infoPlist: infoPlist,
            quickLookHTML: Self.renderHTML(title: title, profile: parsedProfile, infoPlist: infoPlist)
        )
    }

    private func findApplicationBundle(in directory: URL) throws -> URL {
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        if let applicationURL = contents.first(where: { $0.pathExtension.lowercased() == "app" }) {
            return applicationURL
        }

        throw ParserError.unsupportedFile(directory)
    }

    private func runProcess(launchPath: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ParserError.unreadableData(URL(fileURLWithPath: arguments.last ?? launchPath))
        }
    }

    static func renderHTML(title: String, profile: ParsedProfile?, infoPlist: [String: Any]?) -> String {
        let summaryRows: [(String, String)] = [
            ("名称", profile?.record.displayName ?? title),
            ("Bundle ID", profile?.record.bundleIdentifier ?? "-"),
            ("团队", profile?.record.teamName ?? "-"),
            ("类型", profile?.record.profileType ?? "-"),
            ("平台", profile?.record.profilePlatform ?? "-"),
            ("到期", profile?.record.expirationDateValue.map(Formatters.timestampString(from:)) ?? "-"),
            ("证书", "\(profile?.record.certificateCount ?? 0)"),
            ("设备", "\(profile?.record.deviceCount ?? 0)"),
        ]

        let infoRows = (infoPlist ?? [:]).keys.sorted().prefix(20).map { key in
            "<tr><th>\(escapeHTML(key))</th><td>\(escapeHTML(String(describing: infoPlist?[key] ?? "")))</td></tr>"
        }.joined()

        let certificateRows = (profile?.certificates ?? []).map { certificate in
            "<li><strong>\(escapeHTML(certificate.summary))</strong><br><code>\(escapeHTML(certificate.sha1))</code></li>"
        }.joined()

        let detailRows = summaryRows.map { pair in
            "<tr><th>\(escapeHTML(pair.0))</th><td>\(escapeHTML(pair.1))</td></tr>"
        }.joined()

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 24px; color: #152132; background: linear-gradient(180deg, #f7fafc, #eef3f8); }
        h1 { margin: 0 0 16px; font-size: 28px; }
        h2 { margin: 28px 0 10px; font-size: 18px; }
        .card { background: rgba(255,255,255,0.88); border: 1px solid #dbe4ee; border-radius: 16px; padding: 18px; box-shadow: 0 10px 30px rgba(36, 54, 84, 0.08); }
        table { width: 100%; border-collapse: collapse; }
        th, td { text-align: left; vertical-align: top; padding: 8px 0; border-bottom: 1px solid #ecf1f6; font-size: 13px; }
        th { width: 140px; color: #4f6076; font-weight: 600; }
        code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; word-break: break-all; }
        ul { margin: 0; padding-left: 20px; }
        </style>
        </head>
        <body>
        <h1>\(escapeHTML(title))</h1>
        <div class="card">
        <table>\(detailRows)</table>
        </div>
        <h2>Info.plist</h2>
        <div class="card">
        <table>\(infoRows.isEmpty ? "<tr><td>没有可显示的 Info.plist 数据</td></tr>" : infoRows)</table>
        </div>
        <h2>证书</h2>
        <div class="card">
        <ul>\(certificateRows.isEmpty ? "<li>没有证书数据</li>" : certificateRows)</ul>
        </div>
        </body>
        </html>
        """
    }
}

private func escapeHTML(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}
