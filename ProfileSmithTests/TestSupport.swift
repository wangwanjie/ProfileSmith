import Foundation
import Testing
@testable import ProfileSmith

struct TestTemporaryDirectory {
    let url: URL

    init(prefix: String = "ProfileSmithTests") throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        url = root.appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func makeDirectory(named name: String) throws -> URL {
        let directoryURL = url.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }
}

enum TestFixtureFactory {
    static func writeProfile(
        to directoryURL: URL,
        fileName: String,
        name: String,
        uuid: String,
        teamName: String,
        teamIdentifier: String,
        bundleIdentifier: String,
        profileType: String = "development",
        platform: String = "iOS",
        creationDate: Date = Date(timeIntervalSince1970: 1_700_000_000),
        expirationDate: Date = Date(timeIntervalSince1970: 1_900_000_000)
    ) throws -> URL {
        let fileExtension = platform == "Mac" ? "provisionprofile" : "mobileprovision"
        let profileURL = directoryURL.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
        let plist = makePlist(
            name: name,
            uuid: uuid,
            teamName: teamName,
            teamIdentifier: teamIdentifier,
            bundleIdentifier: bundleIdentifier,
            profileType: profileType,
            platform: platform,
            creationDate: creationDate,
            expirationDate: expirationDate
        )
        let data = try wrappedProfileData(from: plist)
        try data.write(to: profileURL)
        return profileURL
    }

    static func writeApplicationBundle(
        to directoryURL: URL,
        appName: String,
        displayName: String,
        bundleIdentifier: String,
        embeddedProfileURL: URL?
    ) throws -> URL {
        let appURL = directoryURL.appendingPathComponent(appName).appendingPathExtension("app")
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)

        let infoPlist: [String: Any] = [
            "CFBundleDisplayName": displayName,
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleName": appName,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
        ]
        let infoData = try PropertyListSerialization.data(fromPropertyList: infoPlist, format: .xml, options: 0)
        try infoData.write(to: appURL.appendingPathComponent("Info.plist"))

        if let embeddedProfileURL {
            try FileManager.default.copyItem(
                at: embeddedProfileURL,
                to: appURL.appendingPathComponent("embedded.mobileprovision")
            )
        }

        return appURL
    }

    static func writeIPA(
        to directoryURL: URL,
        name: String,
        appDisplayName: String,
        bundleIdentifier: String,
        embeddedProfileURL: URL?
    ) throws -> URL {
        let payloadDirectory = directoryURL.appendingPathComponent("Payload", isDirectory: true)
        try FileManager.default.createDirectory(at: payloadDirectory, withIntermediateDirectories: true)
        _ = try writeApplicationBundle(
            to: payloadDirectory,
            appName: name,
            displayName: appDisplayName,
            bundleIdentifier: bundleIdentifier,
            embeddedProfileURL: embeddedProfileURL
        )

        let ipaURL = directoryURL.appendingPathComponent(name).appendingPathExtension("ipa")
        try runProcess(
            executable: "/usr/bin/ditto",
            arguments: ["-c", "-k", "--sequesterRsrc", "--keepParent", payloadDirectory.path, ipaURL.path]
        )
        return ipaURL
    }

    static func makeRecord(
        path: String,
        name: String,
        teamName: String,
        bundleIdentifier: String,
        profileType: String,
        profilePlatform: String,
        isExpired: Bool,
        daysUntilExpiration: Int?,
        expirationDate: TimeInterval,
        modificationTime: TimeInterval = 1_700_000_000
    ) -> ProfileRecord {
        ProfileRecord(
            path: path,
            sourceKind: ScanLocation.Kind.custom.rawValue,
            sourceName: "Tests",
            fileName: URL(fileURLWithPath: path).lastPathComponent,
            fileExtension: URL(fileURLWithPath: path).pathExtension,
            fileSize: 128,
            fileModificationTime: modificationTime,
            fileCreationTime: modificationTime,
            uuid: UUID().uuidString,
            name: name,
            teamName: teamName,
            teamIdentifier: "TEAM1234",
            appIDName: name,
            applicationIdentifier: "TEAM1234.\(bundleIdentifier)",
            bundleIdentifier: bundleIdentifier,
            applicationIdentifierPrefix: "TEAM1234",
            profilePlatform: profilePlatform,
            profileType: profileType,
            isExpired: isExpired,
            daysUntilExpiration: daysUntilExpiration,
            creationDate: modificationTime - 10_000,
            expirationDate: expirationDate,
            certificateCount: 0,
            deviceCount: profileType == "Development" ? 2 : 0,
            searchText: "\(name)\n\(bundleIdentifier)\n\(teamName)\n\(profileType)",
            lastIndexedAt: modificationTime
        )
    }

    private static func makePlist(
        name: String,
        uuid: String,
        teamName: String,
        teamIdentifier: String,
        bundleIdentifier: String,
        profileType: String,
        platform: String,
        creationDate: Date,
        expirationDate: Date
    ) -> [String: Any] {
        let isDevelopment = profileType == "development"
        let hasDevices = profileType == "development" || profileType == "adhoc"
        let isEnterprise = profileType == "enterprise"

        var plist: [String: Any] = [
            "Name": name,
            "UUID": uuid,
            "TeamName": teamName,
            "TeamIdentifier": [teamIdentifier],
            "ApplicationIdentifierPrefix": [teamIdentifier],
            "AppIDName": name,
            "CreationDate": creationDate,
            "ExpirationDate": expirationDate,
            "Platform": [platform],
            "DeveloperCertificates": [],
            "Entitlements": [
                "application-identifier": "\(teamIdentifier).\(bundleIdentifier)",
                "get-task-allow": isDevelopment,
            ],
        ]

        if hasDevices {
            plist["ProvisionedDevices"] = ["DEVICE-001", "DEVICE-002"]
        }
        if isEnterprise {
            plist["ProvisionsAllDevices"] = true
        }
        return plist
    }

    private static func wrappedProfileData(from plist: [String: Any]) throws -> Data {
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        var data = Data("FAKECMS\n".utf8)
        data.append(plistData)
        data.append(Data("\nFAKECMS-END".utf8))
        return data
    }

    private static func runProcess(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw NSError(
                domain: "ProfileSmithTests.Process",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Process failed: \(executable) \(arguments.joined(separator: " "))"]
            )
        }
    }
}
