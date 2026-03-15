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
}

