import Foundation
import Testing
@testable import ProfileSmith

struct ProfileScannerTests {
    @Test
    func incrementalScanOnlyReindexesChangedFilesAndRemovesDeletedFiles() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let scanDirectory = try temporaryDirectory.makeDirectory(named: "Scan")
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": scanDirectory.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
        ]

        let paths = try ProfileSupportPaths(bundle: .main, environment: environment)
        let parser = MobileProvisionParser()
        let database = try ProfileDatabase(databaseURL: paths.databaseURL)
        defer { try? database.close() }
        let scanner = ProfileScanner(paths: paths, parser: parser, database: database)

        let profileURL = try TestFixtureFactory.writeProfile(
            to: scanDirectory,
            fileName: "alpha-dev",
            name: "Alpha Dev",
            uuid: "SCAN-AAAA-BBBB-CCCC-DDDD",
            teamName: "Alpha Team",
            teamIdentifier: "ALPHA1234",
            bundleIdentifier: "com.example.alpha"
        )

        let firstScan = try scanner.scan(forceReindex: false)
        #expect(firstScan.changedCount == 1)
        #expect(firstScan.removedCount == 0)

        let secondScan = try scanner.scan(forceReindex: false)
        #expect(secondScan.changedCount == 0)
        #expect(secondScan.removedCount == 0)

        let updatedProfileURL = try TestFixtureFactory.writeProfile(
            to: scanDirectory,
            fileName: "alpha-dev",
            name: "Alpha Dev Updated",
            uuid: "SCAN-AAAA-BBBB-CCCC-DDDD",
            teamName: "Alpha Team",
            teamIdentifier: "ALPHA1234",
            bundleIdentifier: "com.example.alpha"
        )
        #expect(updatedProfileURL.path == profileURL.path)

        let thirdScan = try scanner.scan(forceReindex: false)
        #expect(thirdScan.changedCount == 1)
        #expect(thirdScan.removedCount == 0)

        try FileManager.default.removeItem(at: profileURL)

        let fourthScan = try scanner.scan(forceReindex: false)
        #expect(fourthScan.changedCount == 0)
        #expect(fourthScan.removedCount == 1)

        let remainingProfiles = try database.fetchProfiles(query: ProfileQuery())
        #expect(remainingProfiles.isEmpty)
    }
}
