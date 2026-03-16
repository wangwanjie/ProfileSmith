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
        let entitlements = profile?.plist["Entitlements"] as? [String: Any] ?? [:]
        let summaryRows: [(String, String)] = [
            ("名称", profile?.record.displayName ?? title),
            ("Bundle ID", profile?.record.bundleIdentifier ?? "-"),
            ("App ID Name", profile?.record.appIDName ?? "-"),
            ("团队", profile?.record.teamName ?? "-"),
            ("Team ID", profile?.record.teamIdentifier ?? "-"),
            ("类型", profile?.record.profileType ?? "-"),
            ("平台", profile?.record.profilePlatform ?? "-"),
            ("UUID", profile?.record.uuid ?? "-"),
            ("创建", profile?.record.creationDateValue.map(Formatters.timestampString(from:)) ?? "-"),
            ("到期", profile?.record.expirationDateValue.map(Formatters.timestampString(from:)) ?? "-"),
            ("Application ID", profile?.record.applicationIdentifier ?? "-"),
            ("证书", "\(profile?.record.certificateCount ?? 0)"),
            ("设备", "\(profile?.record.deviceCount ?? 0)"),
        ]

        let entitlementRows = entitlements.keys.sorted().map { key in
            "<tr><th>\(escapeHTML(key))</th><td><code>\(escapeHTML(String(describing: entitlements[key] ?? "")))</code></td></tr>"
        }.joined()

        let infoRows = (infoPlist ?? [:]).keys.sorted().prefix(20).map { key in
            "<tr><th>\(escapeHTML(key))</th><td><code>\(escapeHTML(String(describing: infoPlist?[key] ?? "")))</code></td></tr>"
        }.joined()

        let certificateRows = (profile?.certificates ?? []).map { certificate in
            "<li><strong>\(escapeHTML(certificate.summary))</strong><code>\(escapeHTML(certificate.sha1))</code></li>"
        }.joined()

        let detailRows = summaryRows.map { pair in
            "<tr><th>\(escapeHTML(pair.0))</th><td>\(escapeHTML(pair.1))</td></tr>"
        }.joined()

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light dark">
        <style>
        :root {
            color-scheme: light dark;
            --ink:#152132;
            --muted:#5d7084;
            --line:rgba(21,33,50,0.10);
            --card:rgba(255,255,255,0.92);
            --card-strong:#ffffff;
            --accent:#1e6fd9;
            --tint:rgba(30,111,217,0.12);
            --shadow:0 16px 36px rgba(36,54,84,0.10);
            --header-bg:rgba(21,33,50,0.03);
            --bg-top:#f5f8fc;
            --bg-bottom:#e9eff6;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --ink:#e8eef7;
                --muted:#9badc2;
                --line:rgba(194,208,228,0.14);
                --card:rgba(18,25,35,0.94);
                --card-strong:rgba(24,33,45,0.98);
                --accent:#7cb2ff;
                --tint:rgba(124,178,255,0.16);
                --shadow:0 18px 40px rgba(0,0,0,0.34);
                --header-bg:rgba(255,255,255,0.04);
                --bg-top:#121923;
                --bg-bottom:#0b1017;
            }
        }
        * { box-sizing: border-box; }
        html { background: var(--bg-bottom); }
        body {
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            margin: 0;
            padding: 18px;
            color: var(--ink);
            background:
                radial-gradient(circle at top left, rgba(98,146,220,0.18), transparent 30%),
                linear-gradient(180deg, var(--bg-top), var(--bg-bottom));
        }
        .page { max-width: 920px; margin: 0 auto; }
        .stack { display:flex; flex-direction:column; gap:16px; }
        .hero {
            padding:22px 24px;
            border:1px solid var(--line);
            border-radius:18px;
            background:var(--card);
            box-shadow:var(--shadow);
        }
        .badge {
            display:inline-flex;
            align-items:center;
            margin-bottom:12px;
            padding:8px 12px;
            border-radius:999px;
            background:var(--tint);
            color:var(--accent);
            font-size:12px;
            font-weight:700;
            letter-spacing:0.08em;
            text-transform:uppercase;
        }
        h1 { margin: 0; font-size: 28px; line-height: 1.15; }
        .subtitle { margin-top:8px; color:var(--muted); font-size:14px; }
        .card {
            background: var(--card);
            border: 1px solid var(--line);
            border-radius: 16px;
            overflow:hidden;
            box-shadow: var(--shadow);
        }
        .card h2 {
            margin:0;
            padding:16px 18px 10px;
            font-size:18px;
            background:linear-gradient(180deg, var(--header-bg), transparent);
        }
        table { width: 100%; border-collapse: collapse; }
        th, td {
            text-align: left;
            vertical-align: top;
            padding: 11px 18px;
            border-top: 1px solid var(--line);
            font-size: 13px;
            line-height: 1.55;
        }
        th {
            width: 176px;
            color: var(--muted);
            font-weight: 600;
            white-space: nowrap;
        }
        td { color: var(--ink); overflow-wrap: anywhere; }
        code {
            display:block;
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            font-size: 12px;
            line-height: 1.55;
            white-space: pre-wrap;
            word-break: break-word;
            overflow-wrap: anywhere;
        }
        ul {
            list-style: none;
            margin: 0;
            padding: 0 18px 18px;
        }
        li {
            margin: 0;
            padding: 14px 0;
            border-top: 1px solid var(--line);
        }
        strong {
            display:block;
            margin-bottom:6px;
            font-size:13px;
        }
        .empty { padding: 0 18px 18px; color:var(--muted); font-size:13px; }
        @media (max-width: 760px) {
            body { padding: 14px; }
            .hero { padding: 18px; }
            h1 { font-size: 24px; }
            th { width: 136px; }
        }
        @media (max-width: 520px) {
            table, tbody, tr, th, td { display: block; width: 100%; }
            th { padding-bottom: 4px; border-top: 1px solid var(--line); }
            td { padding-top: 0; padding-bottom: 12px; }
        }
        </style>
        </head>
        <body>
        <div class="page">
            <div class="stack">
                <section class="hero">
                    <div class="badge">Preview</div>
                    <h1>\(escapeHTML(title))</h1>
                    <div class="subtitle">在当前窗口中查看描述文件概要、Entitlements、Info.plist 与证书摘要。</div>
                </section>
                <section class="card">
                    <h2>概要</h2>
                    <table>\(detailRows)</table>
                </section>
                <section class="card">
                    <h2>Entitlements</h2>
                    \(entitlementRows.isEmpty ? "<div class=\"empty\">没有可显示的 Entitlements</div>" : "<table>\(entitlementRows)</table>")
                </section>
                <section class="card">
                    <h2>Info.plist</h2>
                    \(infoRows.isEmpty ? "<div class=\"empty\">没有可显示的 Info.plist 数据</div>" : "<table>\(infoRows)</table>")
                </section>
                <section class="card">
                    <h2>证书</h2>
                    \(certificateRows.isEmpty ? "<div class=\"empty\">没有证书数据</div>" : "<ul>\(certificateRows)</ul>")
                </section>
            </div>
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
