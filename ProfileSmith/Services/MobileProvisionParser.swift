import Foundation
import Security
import CommonCrypto

struct CertificateSummary: Equatable {
    var summary: String
    var invalidityDate: Date?
    var organization: String?
    var sha1: String
    var sha256: String

    var asDictionary: [String: Any] {
        var dictionary: [String: Any] = [
            "summary": summary,
            "sha1": sha1,
            "sha256": sha256,
        ]
        if let invalidityDate {
            dictionary["invalidity"] = invalidityDate
        }
        if let organization {
            dictionary["organization"] = organization
        }
        return dictionary
    }

    static func fromRawData(_ data: Data) -> CertificateSummary {
        MobileProvisionParser.parseCertificate(data) ?? CertificateSummary(
            summary: "Certificate",
            invalidityDate: nil,
            organization: nil,
            sha1: MobileProvisionParser.digestString(for: data, algorithm: .sha1),
            sha256: MobileProvisionParser.digestString(for: data, algorithm: .sha256)
        )
    }
}

struct ParsedProfile {
    let record: ProfileRecord
    let plist: [String: Any]
    let plistXML: String
    let certificates: [CertificateSummary]
}

enum ParserError: LocalizedError {
    case unsupportedFile(URL)
    case unreadableData(URL)
    case missingEmbeddedPlist(URL)
    case malformedPropertyList(URL)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let url):
            return "不支持的描述文件格式: \(url.lastPathComponent)"
        case .unreadableData(let url):
            return "无法读取文件: \(url.path)"
        case .missingEmbeddedPlist(let url):
            return "未在文件中找到可解析的 plist: \(url.lastPathComponent)"
        case .malformedPropertyList(let url):
            return "plist 结构无法解析: \(url.lastPathComponent)"
        }
    }
}

final class MobileProvisionParser {
    nonisolated func parseProfile(at url: URL, sourceLocation: ScanLocation) throws -> ParsedProfile {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try parseProfile(data: data, fileURL: url, sourceLocation: sourceLocation)
    }

    nonisolated func parseProfile(data: Data, fileURL: URL, sourceLocation: ScanLocation) throws -> ParsedProfile {
        let plistXML = try extractPlistXML(from: data, fileURL: fileURL)
        guard let plistData = plistXML.data(using: .utf8) else {
            throw ParserError.malformedPropertyList(fileURL)
        }

        var format = PropertyListSerialization.PropertyListFormat.xml
        let object = try PropertyListSerialization.propertyList(from: plistData, options: [], format: &format)
        guard let plist = object as? [String: Any] else {
            throw ParserError.malformedPropertyList(fileURL)
        }

        let fileManager = FileManager.default
        let attributes = (try? fileManager.attributesOfItem(atPath: fileURL.path)) ?? [:]
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? Int64(data.count)
        let modificationDate = (attributes[.modificationDate] as? Date) ?? Date()
        let creationDate = (attributes[.creationDate] as? Date) ?? modificationDate

        let certificatesData = plist["DeveloperCertificates"] as? [Data] ?? []
        let certificateSummaries = certificatesData.compactMap(Self.parseCertificate(_:))

        let applicationIdentifier = (plist["Entitlements"] as? [String: Any])?["application-identifier"] as? String
        let applicationIdentifierPrefix = (plist["ApplicationIdentifierPrefix"] as? [String])?.first
        let bundleIdentifier = Self.bundleIdentifier(
            applicationIdentifier: applicationIdentifier,
            prefix: applicationIdentifierPrefix
        )
        let expirationDate = plist["ExpirationDate"] as? Date
        let isExpired = expirationDate.map { $0 < Date() } ?? false
        let daysUntilExpiration = expirationDate.map(Self.daysUntilExpiration(for:))
        let profileType = Self.profileType(from: plist, fileExtension: fileURL.pathExtension.lowercased())
        let platform = Self.profilePlatform(from: plist, fileExtension: fileURL.pathExtension.lowercased())
        let searchText = Self.flatten(value: plist)

        let record = ProfileRecord(
            path: fileURL.path,
            sourceKind: sourceLocation.kind.rawValue,
            sourceName: sourceLocation.displayName,
            fileName: fileURL.lastPathComponent,
            fileExtension: fileURL.pathExtension.lowercased(),
            fileSize: fileSize,
            fileModificationTime: modificationDate.timeIntervalSince1970,
            fileCreationTime: creationDate.timeIntervalSince1970,
            uuid: plist["UUID"] as? String,
            name: plist["Name"] as? String,
            teamName: plist["TeamName"] as? String,
            teamIdentifier: (plist["TeamIdentifier"] as? [String])?.joined(separator: ", "),
            appIDName: plist["AppIDName"] as? String,
            applicationIdentifier: applicationIdentifier,
            bundleIdentifier: bundleIdentifier,
            applicationIdentifierPrefix: applicationIdentifierPrefix,
            profilePlatform: platform,
            profileType: profileType,
            isExpired: isExpired,
            daysUntilExpiration: daysUntilExpiration,
            creationDate: (plist["CreationDate"] as? Date)?.timeIntervalSince1970,
            expirationDate: expirationDate?.timeIntervalSince1970,
            certificateCount: certificateSummaries.count,
            deviceCount: (plist["ProvisionedDevices"] as? [String])?.count ?? 0,
            searchText: searchText,
            lastIndexedAt: Date().timeIntervalSince1970
        )

        return ParsedProfile(
            record: record,
            plist: plist,
            plistXML: plistXML,
            certificates: certificateSummaries
        )
    }

    nonisolated func extractPlistXML(from data: Data, fileURL: URL) throws -> String {
        let startToken = Data("<?xml".utf8)
        let endToken = Data("</plist>".utf8)

        guard let startRange = data.range(of: startToken),
              let endRange = data.range(of: endToken, options: .backwards),
              endRange.upperBound >= startRange.lowerBound
        else {
            throw ParserError.missingEmbeddedPlist(fileURL)
        }

        let plistData = data[startRange.lowerBound..<endRange.upperBound]
        guard let string = String(data: plistData, encoding: .utf8) else {
            throw ParserError.malformedPropertyList(fileURL)
        }

        return string
    }

    nonisolated static func profileType(from plist: [String: Any], fileExtension: String) -> String {
        let entitlements = plist["Entitlements"] as? [String: Any]
        let getTaskAllow = entitlements?["get-task-allow"] as? Bool ?? false
        let hasDevices = (plist["ProvisionedDevices"] as? [String])?.isEmpty == false
        let isEnterprise = plist["ProvisionsAllDevices"] as? Bool ?? false

        if fileExtension == "provisionprofile" {
            return hasDevices ? "Development" : "Distribution (App Store)"
        }
        if hasDevices {
            return getTaskAllow ? "Development" : "Distribution (Ad Hoc)"
        }
        return isEnterprise ? "Enterprise" : "Distribution (App Store)"
    }

    nonisolated static func profilePlatform(from plist: [String: Any], fileExtension: String) -> String {
        if fileExtension == "provisionprofile" {
            return "Mac"
        }
        if let platforms = plist["Platform"] as? [String], let platform = platforms.first {
            return platform
        }
        return "iOS"
    }

    nonisolated static func bundleIdentifier(applicationIdentifier: String?, prefix: String?) -> String? {
        guard let applicationIdentifier else { return nil }
        guard let prefix, applicationIdentifier.hasPrefix(prefix + ".") else { return applicationIdentifier }
        return String(applicationIdentifier.dropFirst(prefix.count + 1))
    }

    nonisolated static func daysUntilExpiration(for date: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let from = calendar.startOfDay(for: Date())
        let to = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }

    nonisolated static func flatten(value: Any) -> String {
        var lines: [String] = []
        collectFlattenedValues(from: value, keyPath: nil, into: &lines)
        return lines.joined(separator: "\n")
    }

    private nonisolated static func collectFlattenedValues(from value: Any, keyPath: String?, into lines: inout [String]) {
        switch value {
        case let dictionary as [String: Any]:
            for key in dictionary.keys.sorted() {
                let childKeyPath = [keyPath, key].compactMap { $0 }.joined(separator: ".")
                collectFlattenedValues(from: dictionary[key] as Any, keyPath: childKeyPath, into: &lines)
            }
        case let array as [Any]:
            for (index, item) in array.enumerated() {
                let childKeyPath = [keyPath, "\(index)"].compactMap { $0 }.joined(separator: ".")
                collectFlattenedValues(from: item, keyPath: childKeyPath, into: &lines)
            }
        case let date as Date:
            lines.append([keyPath, Formatters.timestampString(from: date)].compactMap { $0 }.joined(separator: ": "))
        case let data as Data:
            lines.append([keyPath, data.base64EncodedString()].compactMap { $0 }.joined(separator: ": "))
        default:
            lines.append([keyPath, String(describing: value)].compactMap { $0 }.joined(separator: ": "))
        }
    }

    nonisolated static func parseCertificate(_ data: Data) -> CertificateSummary? {
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            return nil
        }

        let summary = SecCertificateCopySubjectSummary(certificate) as String? ?? "Certificate"
        let sha1 = digestString(for: data, algorithm: .sha1)
        let sha256 = digestString(for: data, algorithm: .sha256)

        let requestedKeys = [kSecOIDX509V1SubjectName, kSecOIDInvalidityDate] as CFArray
        let values = SecCertificateCopyValues(certificate, requestedKeys, nil) as? [CFString: Any]
        let invalidityDate = ((values?[kSecOIDInvalidityDate] as? [CFString: Any])?[kSecPropertyKeyValue] as? Date)

        var organization: String?
        if let subject = values?[kSecOIDX509V1SubjectName] as? [CFString: Any],
           let entries = subject[kSecPropertyKeyValue] as? [[CFString: Any]] {
            organization = entries
                .compactMap { entry -> String? in
                    let label = entry[kSecPropertyKeyLabel] as? String
                    let value = entry[kSecPropertyKeyValue] as? String
                    return label == "O" ? value : nil
                }
                .first
        }

        return CertificateSummary(
            summary: summary,
            invalidityDate: invalidityDate,
            organization: organization,
            sha1: sha1,
            sha256: sha256
        )
    }

    enum DigestAlgorithm {
        case sha1
        case sha256
    }

    nonisolated static func digestString(for data: Data, algorithm: DigestAlgorithm) -> String {
        let length: Int
        let digest: [UInt8]

        switch algorithm {
        case .sha1:
            length = Int(CC_SHA1_DIGEST_LENGTH)
            var buffer = [UInt8](repeating: 0, count: length)
            data.withUnsafeBytes { bytes in
                _ = CC_SHA1(bytes.baseAddress, CC_LONG(data.count), &buffer)
            }
            digest = buffer
        case .sha256:
            length = Int(CC_SHA256_DIGEST_LENGTH)
            var buffer = [UInt8](repeating: 0, count: length)
            data.withUnsafeBytes { bytes in
                _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &buffer)
            }
            digest = buffer
        }

        return digest.map { String(format: "%02X", $0) }.joined()
    }
}
