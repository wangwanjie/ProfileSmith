import Foundation
import Testing
@testable import ProfileSmith

struct MobileProvisionParserTests {
    @Test
    func parsesDevelopmentMobileProvision() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let profileURL = try TestFixtureFactory.writeProfile(
            to: temporaryDirectory.url,
            fileName: "alpha-dev",
            name: "Alpha Dev",
            uuid: "11111111-2222-3333-4444-555555555555",
            teamName: "Alpha Team",
            teamIdentifier: "ALPHA1234",
            bundleIdentifier: "com.example.alpha",
            profileType: "development",
            platform: "iOS"
        )

        let parser = MobileProvisionParser()
        let parsed = try parser.parseProfile(
            at: profileURL,
            sourceLocation: ScanLocation(kind: .custom, url: temporaryDirectory.url, displayName: "Tests")
        )

        #expect(parsed.record.displayName == "Alpha Dev")
        #expect(parsed.record.uuid == "11111111-2222-3333-4444-555555555555")
        #expect(parsed.record.teamName == "Alpha Team")
        #expect(parsed.record.bundleIdentifier == "com.example.alpha")
        #expect(parsed.record.profileType == "Development")
        #expect(parsed.record.profilePlatform == "iOS")
        #expect(parsed.record.deviceCount == 2)
        #expect(parsed.record.isExpired == false)
        #expect(parsed.plistXML.contains("<key>Name</key>"))
    }

    @Test
    func parsesMacProvisionProfile() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let profileURL = try TestFixtureFactory.writeProfile(
            to: temporaryDirectory.url,
            fileName: "beta-mac-store",
            name: "Beta Mac Store",
            uuid: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
            teamName: "Beta Team",
            teamIdentifier: "BETA1234",
            bundleIdentifier: "com.example.beta.mac",
            profileType: "distribution",
            platform: "Mac"
        )

        let parser = MobileProvisionParser()
        let parsed = try parser.parseProfile(
            at: profileURL,
            sourceLocation: ScanLocation(kind: .custom, url: temporaryDirectory.url, displayName: "Tests")
        )

        #expect(parsed.record.profilePlatform == "Mac")
        #expect(parsed.record.profileType == "Distribution (App Store)")
        #expect(parsed.record.deviceCount == 0)
        #expect(parsed.record.bundleIdentifier == "com.example.beta.mac")
    }

    @Test(arguments: [
        ("adhoc", "iOS", "Distribution (Ad Hoc)", 2),
        ("enterprise", "iOS", "Enterprise", 0),
        ("distribution", "iOS", "Distribution (App Store)", 0),
        ("development", "Mac", "Development", 2),
        ("developerid", "Mac", "Distribution (Developer ID)", 0),
    ])
    func classifiesProfileTypes(fixtureType: String, platform: String, expectedType: String, expectedDevices: Int) throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let profileURL = try TestFixtureFactory.writeProfile(
            to: temporaryDirectory.url,
            fileName: "\(fixtureType)-\(platform)",
            name: "Type \(fixtureType)",
            uuid: UUID().uuidString,
            teamName: "Type Team",
            teamIdentifier: "TYPE1234",
            bundleIdentifier: "com.example.type",
            profileType: fixtureType,
            platform: platform
        )

        let parsed = try MobileProvisionParser().parseProfile(
            at: profileURL,
            sourceLocation: ScanLocation(kind: .custom, url: temporaryDirectory.url, displayName: "Tests")
        )

        #expect(parsed.record.profileType == expectedType)
        #expect(parsed.record.profilePlatform == platform)
        #expect(parsed.record.deviceCount == expectedDevices)
    }

    @Test
    func rejectsFilesWithoutEmbeddedPlist() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let corruptURL = try TestFixtureFactory.writeCorruptProfile(to: temporaryDirectory.url, fileName: "corrupt")
        #expect(throws: ParserError.self) {
            _ = try MobileProvisionParser().parseProfile(
                at: corruptURL,
                sourceLocation: ScanLocation(kind: .custom, url: temporaryDirectory.url, displayName: "Tests")
            )
        }
    }

    @Test
    func bundleIdentifierStripsOnlyMatchingTeamPrefix() {
        #expect(MobileProvisionParser.bundleIdentifier(applicationIdentifier: "TEAM1234.com.example.app", prefix: "TEAM1234") == "com.example.app")
        #expect(MobileProvisionParser.bundleIdentifier(applicationIdentifier: "TEAM1234.*", prefix: "TEAM1234") == "*")
        // 前缀不匹配时保留原值，避免误删 Bundle ID 的一部分。
        #expect(MobileProvisionParser.bundleIdentifier(applicationIdentifier: "OTHER.com.example.app", prefix: "TEAM1234") == "OTHER.com.example.app")
        #expect(MobileProvisionParser.bundleIdentifier(applicationIdentifier: "com.example.app", prefix: nil) == "com.example.app")
        #expect(MobileProvisionParser.bundleIdentifier(applicationIdentifier: nil, prefix: "TEAM1234") == nil)
    }

    @Test
    func daysUntilExpirationCountsCalendarDaysAndNeverGoesNegative() throws {
        let calendar = Calendar(identifier: .gregorian)
        let reference = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 23, minute: 30)))
        let nextMorning = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 11, hour: 0, minute: 30)))
        let sameDayLater = try #require(calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 23, minute: 59)))
        let past = try #require(calendar.date(from: DateComponents(year: 2025, month: 12, day: 1)))

        #expect(MobileProvisionParser.daysUntilExpiration(for: nextMorning, referenceDate: reference) == 1)
        #expect(MobileProvisionParser.daysUntilExpiration(for: sameDayLater, referenceDate: reference) == 0)
        #expect(MobileProvisionParser.daysUntilExpiration(for: past, referenceDate: reference) == 0)
    }

    @Test
    func certificateExportWritesDERForCerAndPEMForPem() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let paths = try ProfileSupportPaths(bundle: .main, environment: [
            "PROFILESMITH_SCAN_DIRECTORIES": try temporaryDirectory.makeDirectory(named: "Scan").path,
            "PROFILESMITH_SUPPORT_DIRECTORY": try temporaryDirectory.makeDirectory(named: "Support").path,
        ])
        let fileOperations = ProfileFileOperations(paths: paths, parser: MobileProvisionParser())
        let certificateData = Data((0..<100).map { UInt8($0) })

        let derURL = temporaryDirectory.url.appendingPathComponent("cert.cer")
        try fileOperations.exportCertificate(data: certificateData, to: derURL)
        #expect(try Data(contentsOf: derURL) == certificateData)

        let pemURL = temporaryDirectory.url.appendingPathComponent("cert.pem")
        try fileOperations.exportCertificate(data: certificateData, to: pemURL)
        let pem = try String(contentsOf: pemURL, encoding: .utf8)
        #expect(pem.hasPrefix("-----BEGIN CERTIFICATE-----\n"))
        #expect(pem.hasSuffix("-----END CERTIFICATE-----\n"))
        let body = pem
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        #expect(Data(base64Encoded: body) == certificateData)
    }
}
