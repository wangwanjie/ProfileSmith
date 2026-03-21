import CommonCrypto
import Foundation
import Security

enum QuickLookInspectionError: LocalizedError {
    case unsupportedFile(URL)
    case unreadableData(URL)
    case missingEmbeddedPlist(URL)
    case malformedPropertyList(URL)
    case missingApplicationBundle(URL)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let url):
            return QuickLookL10n.unsupportedFile(url.lastPathComponent)
        case .unreadableData(let url):
            return QuickLookL10n.unreadableData(url.path)
        case .missingEmbeddedPlist(let url):
            return QuickLookL10n.missingEmbeddedPlist(url.lastPathComponent)
        case .malformedPropertyList(let url):
            return QuickLookL10n.malformedPropertyList(url.lastPathComponent)
        case .missingApplicationBundle(let url):
            return QuickLookL10n.missingApplicationBundle(url.path)
        }
    }
}

private struct ParsedProfileDetails {
    let title: String
    let bundleIdentifier: String?
    let appIDName: String?
    let teamName: String?
    let teamIdentifier: String?
    let profileType: String
    let platform: String
    let uuid: String?
    let creationDate: Date?
    let expirationDate: Date?
    let applicationIdentifier: String?
    let certificateCount: Int
    let deviceCount: Int
    let entitlements: [(key: String, value: String)]
    let certificates: [(summary: String, digest: String)]
}

final class ProfileSmithQuickLookInspector {
    func inspect(url: URL) throws -> QuickLookInspection {
        let fileKind = QuickLookFileKind(url: url)
        switch fileKind {
        case .mobileProvision, .provisionProfile:
            let profile = try parseProfile(at: url)
            return QuickLookInspection(
                fileURL: url,
                fileKind: fileKind,
                title: profile.title,
                bundleIdentifier: profile.bundleIdentifier,
                appIDName: profile.appIDName,
                teamName: profile.teamName,
                teamIdentifier: profile.teamIdentifier,
                profileType: profile.profileType,
                platform: profile.platform,
                uuid: profile.uuid,
                creationDate: profile.creationDate,
                expirationDate: profile.expirationDate,
                applicationIdentifier: profile.applicationIdentifier,
                certificateCount: profile.certificateCount,
                deviceCount: profile.deviceCount,
                entitlements: profile.entitlements,
                infoPlist: nil,
                certificates: profile.certificates
            )
        case .ipa:
            return try inspectIPA(at: url)
        case .xcarchive:
            return try inspectArchive(at: url)
        case .appExtension, .application:
            return try inspectApplicationBundle(at: url, fileKind: fileKind, sourceURL: url)
        case .unknown:
            throw QuickLookInspectionError.unsupportedFile(url)
        }
    }

    private func inspectIPA(at url: URL) throws -> QuickLookInspection {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("ProfileSmithQuickLook-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        try run(executable: "/usr/bin/ditto", arguments: ["-x", "-k", url.path, temporaryDirectory.path])
        let applicationURL = try findApplicationBundle(in: temporaryDirectory.appendingPathComponent("Payload", isDirectory: true))
        return try inspectApplicationBundle(at: applicationURL, fileKind: .ipa, sourceURL: url)
    }

    private func inspectArchive(at url: URL) throws -> QuickLookInspection {
        let applicationsDirectory = url
            .appendingPathComponent("Products", isDirectory: true)
            .appendingPathComponent("Applications", isDirectory: true)
        let applicationURL = try findApplicationBundle(in: applicationsDirectory)
        return try inspectApplicationBundle(at: applicationURL, fileKind: .xcarchive, sourceURL: url)
    }

    private func inspectApplicationBundle(at bundleURL: URL, fileKind: QuickLookFileKind, sourceURL: URL) throws -> QuickLookInspection {
        let infoPlistURL = bundleURL.appendingPathComponent("Info.plist", isDirectory: false)
        let embeddedProfileURL = bundleURL.appendingPathComponent("embedded.mobileprovision", isDirectory: false)

        let infoPlist = NSDictionary(contentsOf: infoPlistURL) as? [String: Any]
        let title = (infoPlist?["CFBundleDisplayName"] as? String)
            ?? (infoPlist?["CFBundleName"] as? String)
            ?? bundleURL.deletingPathExtension().lastPathComponent

        if FileManager.default.fileExists(atPath: embeddedProfileURL.path) {
            let profile = try parseProfile(at: embeddedProfileURL)
            return QuickLookInspection(
                fileURL: sourceURL,
                fileKind: fileKind,
                title: title,
                bundleIdentifier: profile.bundleIdentifier ?? (infoPlist?["CFBundleIdentifier"] as? String),
                appIDName: profile.appIDName,
                teamName: profile.teamName,
                teamIdentifier: profile.teamIdentifier,
                profileType: profile.profileType,
                platform: profile.platform,
                uuid: profile.uuid,
                creationDate: profile.creationDate,
                expirationDate: profile.expirationDate,
                applicationIdentifier: profile.applicationIdentifier,
                certificateCount: profile.certificateCount,
                deviceCount: profile.deviceCount,
                entitlements: profile.entitlements,
                infoPlist: infoPlist,
                certificates: profile.certificates
            )
        }

        return QuickLookInspection(
            fileURL: sourceURL,
            fileKind: fileKind,
            title: title,
            bundleIdentifier: infoPlist?["CFBundleIdentifier"] as? String,
            appIDName: nil,
            teamName: nil,
            teamIdentifier: nil,
            profileType: fileKind.badgeText,
            platform: (infoPlist?["DTPlatformName"] as? String).map(QuickLookL10n.platform),
            uuid: nil,
            creationDate: nil,
            expirationDate: nil,
            applicationIdentifier: nil,
            certificateCount: 0,
            deviceCount: 0,
            entitlements: [],
            infoPlist: infoPlist,
            certificates: []
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

        throw QuickLookInspectionError.missingApplicationBundle(directory)
    }

    private func parseProfile(at url: URL) throws -> ParsedProfileDetails {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let plistXML = try extractPlistXML(from: data, fileURL: url)

        guard let plistData = plistXML.data(using: .utf8) else {
            throw QuickLookInspectionError.malformedPropertyList(url)
        }

        var format = PropertyListSerialization.PropertyListFormat.xml
        let object = try PropertyListSerialization.propertyList(from: plistData, options: [], format: &format)
        guard let plist = object as? [String: Any] else {
            throw QuickLookInspectionError.malformedPropertyList(url)
        }

        let certificateData = plist["DeveloperCertificates"] as? [Data] ?? []
        let certificates = certificateData.map {
            (
                summary: Self.certificateSummary(for: $0),
                digest: Self.digestString(for: $0)
            )
        }
        let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
        let applicationIdentifier = (plist["Entitlements"] as? [String: Any])?["application-identifier"] as? String
        let applicationIdentifierPrefix = (plist["ApplicationIdentifierPrefix"] as? [String])?.first

        return ParsedProfileDetails(
            title: plist["Name"] as? String ?? url.deletingPathExtension().lastPathComponent,
            bundleIdentifier: Self.bundleIdentifier(applicationIdentifier: applicationIdentifier, prefix: applicationIdentifierPrefix),
            appIDName: plist["AppIDName"] as? String,
            teamName: plist["TeamName"] as? String,
            teamIdentifier: (plist["TeamIdentifier"] as? [String])?.first,
            profileType: Self.profileType(from: plist, fileExtension: url.pathExtension.lowercased()),
            platform: Self.profilePlatform(from: plist, fileExtension: url.pathExtension.lowercased()),
            uuid: plist["UUID"] as? String,
            creationDate: plist["CreationDate"] as? Date,
            expirationDate: plist["ExpirationDate"] as? Date,
            applicationIdentifier: applicationIdentifier,
            certificateCount: certificates.count,
            deviceCount: (plist["ProvisionedDevices"] as? [String])?.count ?? 0,
            entitlements: Self.entitlementRows(from: entitlements),
            certificates: certificates
        )
    }

    private func extractPlistXML(from data: Data, fileURL: URL) throws -> String {
        let startToken = Data("<?xml".utf8)
        let endToken = Data("</plist>".utf8)

        guard let startRange = data.range(of: startToken),
              let endRange = data.range(of: endToken, options: .backwards),
              endRange.upperBound >= startRange.lowerBound
        else {
            throw QuickLookInspectionError.missingEmbeddedPlist(fileURL)
        }

        let plistData = data[startRange.lowerBound..<endRange.upperBound]
        guard let string = String(data: plistData, encoding: .utf8) else {
            throw QuickLookInspectionError.malformedPropertyList(fileURL)
        }

        return string
    }

    private static func profileType(from plist: [String: Any], fileExtension: String) -> String {
        let entitlements = plist["Entitlements"] as? [String: Any]
        let getTaskAllow = entitlements?["get-task-allow"] as? Bool ?? false
        let hasDevices = (plist["ProvisionedDevices"] as? [String])?.isEmpty == false
        let isEnterprise = plist["ProvisionsAllDevices"] as? Bool ?? false

        if fileExtension == "provisionprofile" {
            return QuickLookL10n.profileType(hasDevices ? "Development" : "Distribution (App Store)")
        }
        if hasDevices {
            return QuickLookL10n.profileType(getTaskAllow ? "Development" : "Distribution (Ad Hoc)")
        }
        return QuickLookL10n.profileType(isEnterprise ? "Enterprise" : "Distribution (App Store)")
    }

    private static func profilePlatform(from plist: [String: Any], fileExtension: String) -> String {
        if fileExtension == "provisionprofile" {
            return QuickLookL10n.platform("Mac")
        }
        if let platforms = plist["Platform"] as? [String], let platform = platforms.first {
            return QuickLookL10n.platform(platform)
        }
        return QuickLookL10n.platform("iOS")
    }

    private static func bundleIdentifier(applicationIdentifier: String?, prefix: String?) -> String? {
        guard let applicationIdentifier else { return nil }
        guard let prefix, applicationIdentifier.hasPrefix(prefix + ".") else { return applicationIdentifier }
        return String(applicationIdentifier.dropFirst(prefix.count + 1))
    }

    private static func digestString(for data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { rawBuffer in
            _ = CC_SHA1(rawBuffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func certificateSummary(for data: Data) -> String {
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            return QuickLookL10n.certificateFallback
        }
        return SecCertificateCopySubjectSummary(certificate) as String? ?? QuickLookL10n.certificateFallback
    }

    private static func entitlementRows(from entitlements: [String: Any]) -> [(key: String, value: String)] {
        entitlements.keys.sorted().map { key in
            (key: key, value: String(describing: entitlements[key] ?? ""))
        }
    }

    private func run(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw QuickLookInspectionError.unreadableData(URL(fileURLWithPath: arguments.last ?? executable))
        }
    }
}
