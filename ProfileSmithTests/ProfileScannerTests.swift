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

    @Test
    func corruptFilesAreSkippedWithoutAbortingTheScan() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let scanDirectory = try temporaryDirectory.makeDirectory(named: "Scan")
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let paths = try ProfileSupportPaths(bundle: .main, environment: [
            "PROFILESMITH_SCAN_DIRECTORIES": scanDirectory.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
        ])
        let database = try ProfileDatabase(databaseURL: paths.databaseURL)
        defer { try? database.close() }
        let scanner = ProfileScanner(paths: paths, parser: MobileProvisionParser(), database: database)

        let validURL = try TestFixtureFactory.writeProfile(
            to: scanDirectory,
            fileName: "valid",
            name: "Valid Profile",
            uuid: "SCAN-VALID-AAAA",
            teamName: "Scan Team",
            teamIdentifier: "SCAN1234",
            bundleIdentifier: "com.example.valid"
        )
        let corruptURL = try TestFixtureFactory.writeCorruptProfile(to: scanDirectory, fileName: "corrupt")

        // /var 是 /private/var 的符号链接，目录枚举返回的路径带 /private 前缀，比较前统一规范化。
        func normalized(_ paths: [String]) -> Set<String> {
            Set(paths.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path })
        }

        // 一个损坏文件不能让整次扫描抛错，有效文件仍然要被索引。
        let result = try scanner.scan(forceReindex: false)
        #expect(result.changedCount == 1)
        #expect(normalized(result.failedPaths) == normalized([corruptURL.path]))
        #expect(normalized(try database.fetchProfiles(query: ProfileQuery()).map(\.path)) == normalized([validURL.path]))

        // 已索引的文件之后损坏时，应从索引中移除，避免继续展示旧内容。
        try Data("broken".utf8).write(to: validURL)
        let secondResult = try scanner.scan(forceReindex: false)
        #expect(secondResult.removedCount == 1)
        #expect(normalized(secondResult.failedPaths) == normalized([validURL.path, corruptURL.path]))
        #expect(try database.fetchProfiles(query: ProfileQuery()).isEmpty)
    }

    @Test
    func missingScanDirectoriesProduceEmptyResult() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let paths = try ProfileSupportPaths(bundle: .main, environment: [
            "PROFILESMITH_SCAN_DIRECTORIES": temporaryDirectory.url.appendingPathComponent("Missing").path,
            "PROFILESMITH_SUPPORT_DIRECTORY": try temporaryDirectory.makeDirectory(named: "Support").path,
        ])
        let database = try ProfileDatabase(databaseURL: paths.databaseURL)
        defer { try? database.close() }

        let result = try ProfileScanner(paths: paths, parser: MobileProvisionParser(), database: database).scan(forceReindex: false)
        #expect(result.changedCount == 0)
        #expect(result.removedCount == 0)
        #expect(result.failedPaths.isEmpty)
    }

    @Test
    func supportedExtensionsAreCaseInsensitive() {
        #expect(ProfileScanner.isSupportedProfileFile(url: URL(fileURLWithPath: "/tmp/a.mobileprovision")))
        #expect(ProfileScanner.isSupportedProfileFile(url: URL(fileURLWithPath: "/tmp/a.MobileProvision")))
        #expect(ProfileScanner.isSupportedProfileFile(url: URL(fileURLWithPath: "/tmp/a.provisionprofile")))
        #expect(!ProfileScanner.isSupportedProfileFile(url: URL(fileURLWithPath: "/tmp/a.ipa")))
        #expect(!ProfileScanner.isSupportedProfileFile(url: URL(fileURLWithPath: "/tmp/mobileprovision")))
    }
}
