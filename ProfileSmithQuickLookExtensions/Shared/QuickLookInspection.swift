import Foundation
#if canImport(AppKit)
import AppKit
#endif

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
    let appIDName: String?
    let teamName: String?
    let teamIdentifier: String?
    let profileType: String?
    let platform: String?
    let uuid: String?
    let creationDate: Date?
    let expirationDate: Date?
    let applicationIdentifier: String?
    let certificateCount: Int
    let deviceCount: Int
    let entitlements: [(key: String, value: String)]
    let infoPlist: [String: Any]?
    let certificates: [(summary: String, digest: String)]

    var statusText: String {
        guard let expirationDate else { return "无到期时间" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        if days < 0 {
            return "已过期"
        }
        if days == 0 {
            return "今天到期"
        }
        if days <= 30 {
            return "\(days) 天内到期"
        }
        return "有效"
    }

    var summaryRows: [QuickLookFieldRow] {
        [
            QuickLookFieldRow(title: "文件", value: fileURL.lastPathComponent),
            QuickLookFieldRow(title: "名称", value: title),
            QuickLookFieldRow(title: "Bundle ID", value: bundleIdentifier ?? "-", isCode: true),
            QuickLookFieldRow(title: "App ID Name", value: appIDName ?? "-"),
            QuickLookFieldRow(title: "团队", value: teamName ?? "-"),
            QuickLookFieldRow(title: "Team ID", value: teamIdentifier ?? "-", isCode: true),
            QuickLookFieldRow(title: "类型", value: profileType ?? fileKind.badgeText),
            QuickLookFieldRow(title: "平台", value: platform ?? "-"),
            QuickLookFieldRow(title: "UUID", value: uuid ?? "-", isCode: true),
            QuickLookFieldRow(title: "创建", value: creationDate.map(QuickLookFormatters.timestampString(from:)) ?? "-"),
            QuickLookFieldRow(title: "到期", value: expirationDate.map(QuickLookFormatters.timestampString(from:)) ?? "-"),
            QuickLookFieldRow(title: "Application ID", value: applicationIdentifier ?? "-", isCode: true),
            QuickLookFieldRow(title: "证书", value: "\(certificateCount)"),
            QuickLookFieldRow(title: "设备", value: "\(deviceCount)"),
        ]
    }

    var entitlementRows: [QuickLookFieldRow] {
        entitlements.map { QuickLookFieldRow(title: $0.key, value: $0.value, isCode: true) }
    }

    var infoRows: [QuickLookFieldRow] {
        (infoPlist ?? [:]).keys.sorted().prefix(24).map { key in
            QuickLookFieldRow(
                title: key,
                value: infoPlist?[key].map { String(describing: $0) } ?? "",
                isCode: true
            )
        }
    }

    var certificateRows: [QuickLookFieldRow] {
        certificates.map { QuickLookFieldRow(title: $0.summary, value: $0.digest, isCode: true) }
    }

    var headerDescription: String {
        switch fileKind {
        case .mobileProvision, .provisionProfile:
            return "展示描述文件核心元数据、Entitlements 和证书摘要。"
        case .ipa, .xcarchive, .appExtension, .application:
            return "优先展示嵌入描述文件，补充可解析的 Info.plist 与签名信息。"
        case .unknown:
            return "当前文件类型无法识别更多结构化信息。"
        }
    }
}

struct QuickLookFieldRow {
    let title: String
    let value: String
    let isCode: Bool

    init(title: String, value: String, isCode: Bool = false) {
        self.title = title
        self.value = value
        self.isCode = isCode
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

#if canImport(AppKit)
extension QuickLookFileKind {
    var accentColor: NSColor {
        NSColor.quickLookColor(hex: accentHex)
    }

    var tintColor: NSColor {
        NSColor.quickLookColor(hex: tintHex)
    }
}

private extension NSColor {
    static func quickLookColor(hex: String) -> NSColor {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let scanner = Scanner(string: cleaned)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        return NSColor(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
