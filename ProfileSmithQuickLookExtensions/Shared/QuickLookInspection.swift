import Foundation
#if canImport(AppKit)
import AppKit
#endif

private enum QuickLookLanguage {
    case english
    case simplifiedChinese
    case traditionalChinese

    var localeIdentifier: String {
        switch self {
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        }
    }

    static func resolve(_ identifier: String?) -> QuickLookLanguage? {
        guard let identifier = identifier?.trimmingCharacters(in: .whitespacesAndNewlines),
              !identifier.isEmpty
        else {
            return nil
        }

        let normalized = identifier.lowercased()
        if normalized.hasPrefix("zh-hant")
            || normalized.hasPrefix("zh-tw")
            || normalized.hasPrefix("zh-hk")
            || normalized.hasPrefix("zh-mo") {
            return .traditionalChinese
        }
        if normalized.hasPrefix("zh") {
            return .simplifiedChinese
        }
        if normalized.hasPrefix("en") {
            return .english
        }
        return nil
    }
}

enum QuickLookL10n {
    private static var language: QuickLookLanguage {
        for identifier in Locale.preferredLanguages {
            if let language = QuickLookLanguage.resolve(identifier) {
                return language
            }
        }
        return .english
    }

    static var locale: Locale {
        Locale(identifier: language.localeIdentifier)
    }

    static func value(_ english: String, _ simplifiedChinese: String, _ traditionalChinese: String) -> String {
        switch language {
        case .english:
            return english
        case .simplifiedChinese:
            return simplifiedChinese
        case .traditionalChinese:
            return traditionalChinese
        }
    }

    static func formatted(_ english: String, _ simplifiedChinese: String, _ traditionalChinese: String, _ arguments: CVarArg...) -> String {
        String(format: value(english, simplifiedChinese, traditionalChinese), locale: locale, arguments: arguments)
    }

    static var unavailableTime: String {
        value("No Expiration", "无到期时间", "無到期時間")
    }

    static var expired: String {
        value("Expired", "已过期", "已過期")
    }

    static var expiresToday: String {
        value("Expires Today", "今天到期", "今天到期")
    }

    static func expiresWithin(_ days: Int) -> String {
        formatted("Expires in %d Days", "%d 天内到期", "%d 天內到期", days)
    }

    static var valid: String {
        value("Valid", "有效", "有效")
    }

    static var rowFile: String { value("File", "文件", "檔案") }
    static var rowName: String { value("Name", "名称", "名稱") }
    static var rowBundleID: String { "Bundle ID" }
    static var rowAppIDName: String { "App ID Name" }
    static var rowTeam: String { value("Team", "团队", "團隊") }
    static var rowTeamID: String { "Team ID" }
    static var rowType: String { value("Type", "类型", "類型") }
    static var rowPlatform: String { value("Platform", "平台", "平台") }
    static var rowUUID: String { "UUID" }
    static var rowCreated: String { value("Created", "创建", "建立") }
    static var rowExpires: String { value("Expires", "到期", "到期") }
    static var rowApplicationID: String { "Application ID" }
    static var rowCertificates: String { value("Certificates", "证书", "證書") }
    static var rowDevices: String { value("Devices", "设备", "裝置") }

    static var headerProfileSummary: String {
        value(
            "Shows the core metadata, entitlements, and certificate summary.",
            "展示描述文件核心元数据、Entitlements 和证书摘要。",
            "展示描述檔核心中繼資料、Entitlements 與證書摘要。"
        )
    }

    static var headerBundleSummary: String {
        value(
            "Prefers embedded profiles, then adds parsed Info.plist and signing details.",
            "优先展示嵌入描述文件，补充可解析的 Info.plist 与签名信息。",
            "優先展示嵌入描述檔，補充可解析的 Info.plist 與簽名資訊。"
        )
    }

    static var headerUnknownSummary: String {
        value(
            "No additional structured data is available for this file type.",
            "当前文件类型无法识别更多结构化信息。",
            "目前檔案類型無法識別更多結構化資訊。"
        )
    }

    static var sectionOverview: String { value("Overview", "概要", "概要") }
    static var sectionOverviewSubtitle: String {
        value(
            "Covers the profile, embedded signing, and key expiration details.",
            "覆盖描述文件、嵌入签名和核心有效期信息。",
            "涵蓋描述檔、嵌入簽名與核心有效期資訊。"
        )
    }
    static var sectionOverviewEmpty: String {
        value("No overview data available.", "没有可显示的概要信息。", "沒有可顯示的概要資訊。")
    }

    static var sectionEntitlements: String { "Entitlements" }
    static var sectionEntitlementsSubtitle: String {
        value(
            "Highlights the application identifier, device capabilities, and debugging permissions first.",
            "优先展示应用标识、设备能力与调试权限。",
            "優先展示應用標識、裝置能力與除錯權限。"
        )
    }
    static var sectionEntitlementsEmpty: String {
        value("No entitlements available.", "没有可显示的 Entitlements。", "沒有可顯示的 Entitlements。")
    }

    static var sectionInfoPlist: String { "Info.plist" }
    static var sectionInfoPlistSubtitle: String {
        value(
            "Shown only when an Info.plist can be parsed from an IPA, app, XCArchive, or APPEX.",
            "仅在 IPA、App、XCArchive 或 APPEX 内解析到 Info.plist 时显示。",
            "僅在 IPA、App、XCArchive 或 APPEX 內解析到 Info.plist 時顯示。"
        )
    }
    static var sectionInfoPlistEmpty: String {
        value("No Info.plist data available.", "没有可显示的 Info.plist 数据。", "沒有可顯示的 Info.plist 資料。")
    }

    static var sectionCertificates: String { value("Certificates", "证书摘要", "證書摘要") }
    static var sectionCertificatesSubtitle: String {
        value(
            "Lists signing certificate subjects and SHA-1 digests.",
            "展示签名证书主题和 SHA-1 摘要。",
            "展示簽名證書主題與 SHA-1 摘要。"
        )
    }
    static var sectionCertificatesEmpty: String {
        value("No certificates available.", "没有可显示的证书摘要。", "沒有可顯示的證書摘要。")
    }

    static var quickLookTitle: String { "Quick Look" }
    static var parseFailed: String { value("Unable to Parse", "无法解析", "無法解析") }
    static func cannotPreview(_ fileName: String) -> String {
        formatted("Unable to Preview %@", "无法预览 %@", "無法預覽 %@", fileName)
    }

    static func unsupportedFile(_ fileName: String) -> String {
        formatted("Unsupported file type: %@", "不支持的文件类型: %@", "不支援的檔案類型: %@", fileName)
    }

    static func unreadableData(_ path: String) -> String {
        formatted("Unable to read file: %@", "无法读取文件: %@", "無法讀取檔案: %@", path)
    }

    static func missingEmbeddedPlist(_ fileName: String) -> String {
        formatted("No embedded plist could be parsed in %@", "未在文件中找到可解析的 plist: %@", "未在檔案中找到可解析的 plist: %@", fileName)
    }

    static func malformedPropertyList(_ fileName: String) -> String {
        formatted("Malformed plist structure: %@", "plist 结构无法解析: %@", "plist 結構無法解析: %@", fileName)
    }

    static func missingApplicationBundle(_ path: String) -> String {
        formatted("Missing application bundle: %@", "没有找到应用包: %@", "找不到應用程式封裝: %@", path)
    }

    static func profileType(_ rawValue: String) -> String {
        switch rawValue {
        case "Development":
            return value("Development", "开发", "開發")
        case "Distribution (App Store)":
            return value("Distribution (App Store)", "分发（App Store）", "發佈（App Store）")
        case "Distribution (Ad Hoc)":
            return value("Distribution (Ad Hoc)", "分发（Ad Hoc）", "發佈（Ad Hoc）")
        case "Enterprise":
            return value("Enterprise", "企业", "企業")
        default:
            return rawValue
        }
    }

    static func platform(_ rawValue: String) -> String {
        let normalized = rawValue.lowercased()
        if normalized == "ios" || normalized == "iphoneos" {
            return "iOS"
        }
        if normalized == "mac" || normalized == "macos" || normalized == "macosx" {
            return "Mac"
        }
        return rawValue
    }

    static func fileKindBadge(_ kind: QuickLookFileKind) -> String {
        switch kind {
        case .mobileProvision:
            return value("iOS Profile", "iOS 描述文件", "iOS 描述檔")
        case .provisionProfile:
            return value("Mac Profile", "Mac 描述文件", "Mac 描述檔")
        case .ipa:
            return "IPA"
        case .xcarchive:
            return "XCArchive"
        case .appExtension:
            return "APPEX"
        case .application:
            return "APP"
        case .unknown:
            return value("File", "文件", "檔案")
        }
    }

    static var certificateFallback: String {
        value("Certificate", "证书", "證書")
    }

    static func thumbnailExpiration(_ timestamp: String) -> String {
        formatted("Expires %@", "到期 %@", "到期 %@", timestamp)
    }
}

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
        QuickLookL10n.fileKindBadge(self)
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
        guard let expirationDate else { return QuickLookL10n.unavailableTime }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        if days < 0 {
            return QuickLookL10n.expired
        }
        if days == 0 {
            return QuickLookL10n.expiresToday
        }
        if days <= 30 {
            return QuickLookL10n.expiresWithin(days)
        }
        return QuickLookL10n.valid
    }

    var summaryRows: [QuickLookFieldRow] {
        [
            QuickLookFieldRow(title: QuickLookL10n.rowFile, value: fileURL.lastPathComponent),
            QuickLookFieldRow(title: QuickLookL10n.rowName, value: title),
            QuickLookFieldRow(title: QuickLookL10n.rowBundleID, value: bundleIdentifier ?? "-", isCode: true),
            QuickLookFieldRow(title: QuickLookL10n.rowAppIDName, value: appIDName ?? "-"),
            QuickLookFieldRow(title: QuickLookL10n.rowTeam, value: teamName ?? "-"),
            QuickLookFieldRow(title: QuickLookL10n.rowTeamID, value: teamIdentifier ?? "-", isCode: true),
            QuickLookFieldRow(title: QuickLookL10n.rowType, value: profileType ?? fileKind.badgeText),
            QuickLookFieldRow(title: QuickLookL10n.rowPlatform, value: platform ?? "-"),
            QuickLookFieldRow(title: QuickLookL10n.rowUUID, value: uuid ?? "-", isCode: true),
            QuickLookFieldRow(title: QuickLookL10n.rowCreated, value: creationDate.map(QuickLookFormatters.timestampString(from:)) ?? "-"),
            QuickLookFieldRow(title: QuickLookL10n.rowExpires, value: expirationDate.map(QuickLookFormatters.timestampString(from:)) ?? "-"),
            QuickLookFieldRow(title: QuickLookL10n.rowApplicationID, value: applicationIdentifier ?? "-", isCode: true),
            QuickLookFieldRow(title: QuickLookL10n.rowCertificates, value: "\(certificateCount)"),
            QuickLookFieldRow(title: QuickLookL10n.rowDevices, value: "\(deviceCount)"),
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
            return QuickLookL10n.headerProfileSummary
        case .ipa, .xcarchive, .appExtension, .application:
            return QuickLookL10n.headerBundleSummary
        case .unknown:
            return QuickLookL10n.headerUnknownSummary
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
    static func timestampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = QuickLookL10n.locale
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMddHHmm")
        return formatter.string(from: date)
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
