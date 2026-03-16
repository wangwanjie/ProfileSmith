import Foundation

enum QuickLookFileKind: String {
    case mobileProvision
    case provisionProfile
    case ipa
    case xcarchive
    case appExtension
    case application
    case unknown

    init(url: URL) {
        switch url.pathExtension.lowercased() {
        case "mobileprovision":
            self = .mobileProvision
        case "provisionprofile":
            self = .provisionProfile
        case "ipa":
            self = .ipa
        case "xcarchive":
            self = .xcarchive
        case "appex":
            self = .appExtension
        case "app":
            self = .application
        default:
            self = .unknown
        }
    }

    var badgeText: String {
        switch self {
        case .mobileProvision:
            return "iOS Profile"
        case .provisionProfile:
            return "Mac Profile"
        case .ipa:
            return "IPA"
        case .xcarchive:
            return "XCArchive"
        case .appExtension:
            return "APPEX"
        case .application:
            return "APP"
        case .unknown:
            return "FILE"
        }
    }

    var accentHex: String {
        switch self {
        case .mobileProvision:
            return "#1E6FD9"
        case .provisionProfile:
            return "#17765D"
        case .ipa:
            return "#C86614"
        case .xcarchive:
            return "#8B5E20"
        case .appExtension:
            return "#B4442A"
        case .application:
            return "#475569"
        case .unknown:
            return "#4B5563"
        }
    }

    var tintHex: String {
        switch self {
        case .mobileProvision:
            return "#EAF3FF"
        case .provisionProfile:
            return "#E9F7F1"
        case .ipa:
            return "#FFF3E8"
        case .xcarchive:
            return "#FAF1E5"
        case .appExtension:
            return "#FFF0EB"
        case .application:
            return "#F1F5F9"
        case .unknown:
            return "#F3F4F6"
        }
    }
}

struct QuickLookInspection {
    let fileURL: URL
    let fileKind: QuickLookFileKind
    let title: String
    let bundleIdentifier: String?
    let teamName: String?
    let profileType: String?
    let platform: String?
    let expirationDate: Date?
    let certificateCount: Int
    let deviceCount: Int
    let infoPlist: [String: Any]?
    let certificateDigests: [String]

    func html() -> String {
        let summaryRows: [(String, String)] = [
            ("文件", fileURL.lastPathComponent),
            ("名称", title),
            ("Bundle ID", bundleIdentifier ?? "-"),
            ("团队", teamName ?? "-"),
            ("类型", profileType ?? fileKind.badgeText),
            ("平台", platform ?? "-"),
            ("到期", expirationDate.map(QuickLookFormatters.timestampString(from:)) ?? "-"),
            ("证书", "\(certificateCount)"),
            ("设备", "\(deviceCount)"),
        ]

        let detailsHTML = summaryRows.map { key, value in
            "<tr><th>\(escapeHTML(key))</th><td>\(escapeHTML(value))</td></tr>"
        }.joined()

        let infoRowsHTML = (infoPlist ?? [:]).keys.sorted().prefix(20).map { key in
            let value = infoPlist?[key].map { String(describing: $0) } ?? ""
            return "<tr><th>\(escapeHTML(key))</th><td>\(escapeHTML(value))</td></tr>"
        }.joined()

        let certificatesHTML = certificateDigests.map { digest in
            "<li><code>\(escapeHTML(digest))</code></li>"
        }.joined()

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root {
            --accent: \(fileKind.accentHex);
            --tint: \(fileKind.tintHex);
            --ink: #122033;
            --muted: #55667d;
            --line: #d9e2ec;
            --card: rgba(255, 255, 255, 0.94);
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            padding: 28px;
            font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
            color: var(--ink);
            background:
                radial-gradient(circle at top left, rgba(255, 255, 255, 0.88), transparent 36%),
                linear-gradient(180deg, #f6f9fc 0%, #edf3f8 100%);
        }
        .hero {
            display: flex;
            align-items: center;
            gap: 14px;
            margin-bottom: 20px;
        }
        .badge {
            padding: 8px 12px;
            border-radius: 999px;
            background: var(--tint);
            color: var(--accent);
            font-size: 12px;
            font-weight: 700;
            letter-spacing: 0.08em;
            text-transform: uppercase;
        }
        h1 {
            margin: 0;
            font-size: 30px;
            line-height: 1.12;
        }
        .subtitle {
            margin-top: 8px;
            color: var(--muted);
            font-size: 14px;
        }
        .grid {
            display: grid;
            gap: 18px;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
        }
        .card {
            background: var(--card);
            border: 1px solid var(--line);
            border-radius: 18px;
            box-shadow: 0 18px 46px rgba(23, 37, 63, 0.08);
            overflow: hidden;
        }
        .card h2 {
            margin: 0;
            padding: 16px 18px 8px;
            font-size: 18px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 10px 18px;
            font-size: 13px;
            line-height: 1.45;
            text-align: left;
            vertical-align: top;
            border-top: 1px solid #edf2f7;
        }
        th {
            width: 128px;
            color: var(--muted);
            font-weight: 600;
        }
        ul {
            margin: 0;
            padding: 0 18px 18px 34px;
        }
        li {
            margin: 0 0 8px;
            color: var(--ink);
        }
        code {
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            font-size: 12px;
            word-break: break-all;
        }
        .empty {
            padding: 18px;
            color: var(--muted);
            font-size: 13px;
        }
        </style>
        </head>
        <body>
            <div class="hero">
                <div class="badge">\(escapeHTML(fileKind.badgeText))</div>
                <div>
                    <h1>\(escapeHTML(title))</h1>
                    <div class="subtitle">\(escapeHTML(fileURL.lastPathComponent))</div>
                </div>
            </div>
            <div class="grid">
                <section class="card">
                    <h2>概要</h2>
                    <table>\(detailsHTML)</table>
                </section>
                <section class="card">
                    <h2>Info.plist</h2>
                    \(infoRowsHTML.isEmpty ? "<div class=\"empty\">没有可显示的 Info.plist 数据</div>" : "<table>\(infoRowsHTML)</table>")
                </section>
                <section class="card">
                    <h2>证书摘要</h2>
                    \(certificatesHTML.isEmpty ? "<div class=\"empty\">没有证书摘要</div>" : "<ul>\(certificatesHTML)</ul>")
                </section>
            </div>
        </body>
        </html>
        """
    }
}

enum QuickLookFormatters {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    static func timestampString(from date: Date) -> String {
        formatter.string(from: date)
    }
}

func escapeHTML(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&#39;")
}
