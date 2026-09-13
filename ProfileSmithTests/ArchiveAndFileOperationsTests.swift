import Foundation
import Testing
@testable import ProfileSmith

struct ArchiveAndFileOperationsTests {
    @Test(arguments: ["ipa", "IPA", "xcarchive", "XCARCHIVE", "app", "APP", "appex", "APPEX"])
    func removedPreviewFormatsCannotBeDropped(_ pathExtension: String) {
        #expect(!DropHostingView.supportsFileURL(URL(fileURLWithPath: "/tmp/Unsupported.\(pathExtension)")))
    }

    @Test(arguments: ["mobileprovision", "provisionprofile", "MOBILEPROVISION", "PROVISIONPROFILE"])
    func provisioningProfilesCanBeDroppedForImport(_ pathExtension: String) {
        #expect(DropHostingView.supportsFileURL(URL(fileURLWithPath: "/tmp/Supported.\(pathExtension)")))
    }

    @Test
    func fileOperationsPreserveExistingFilesOnConflict() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let scanDirectory = try temporaryDirectory.makeDirectory(named: "Profiles")
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let importDirectory = try temporaryDirectory.makeDirectory(named: "Imports")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": scanDirectory.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
        ]

        let paths = try ProfileSupportPaths(bundle: .main, environment: environment)
        let parser = MobileProvisionParser()
        let fileOperations = ProfileFileOperations(paths: paths, parser: parser)

        let firstImport = try TestFixtureFactory.writeProfile(
            to: importDirectory,
            fileName: "shared",
            name: "Shared One",
            uuid: "CONFLICT-AAAA-BBBB-CCCC-DDDD",
            teamName: "Conflict Team",
            teamIdentifier: "CONF1234",
            bundleIdentifier: "com.example.one"
        )
        let secondImport = try TestFixtureFactory.writeProfile(
            to: importDirectory,
            fileName: "shared-two",
            name: "Shared Two",
            uuid: "CONFLICT-AAAA-BBBB-CCCC-DDDD",
            teamName: "Conflict Team",
            teamIdentifier: "CONF1234",
            bundleIdentifier: "com.example.two"
        )

        let firstResult = try fileOperations.importProfiles(from: [firstImport])
        let secondResult = try fileOperations.importProfiles(from: [secondImport])

        #expect(firstResult.installedURLs.count == 1)
        #expect(secondResult.installedURLs.count == 1)
        #expect(firstResult.installedURLs[0].lastPathComponent == "CONFLICT-AAAA-BBBB-CCCC-DDDD.mobileprovision")
        #expect(secondResult.installedURLs[0].lastPathComponent == "CONFLICT-AAAA-BBBB-CCCC-DDDD-2.mobileprovision")
        #expect(FileManager.default.fileExists(atPath: firstResult.installedURLs[0].path))
        #expect(FileManager.default.fileExists(atPath: secondResult.installedURLs[0].path))

        let originalRecord = try parser.parseProfile(at: secondResult.installedURLs[0], sourceLocation: paths.primaryInstallLocation).record
        let beautifiedConflictURL = scanDirectory
            .appendingPathComponent("Shared Two", isDirectory: false)
            .appendingPathExtension("mobileprovision")
        try Data("placeholder".utf8).write(to: beautifiedConflictURL)

        let renamedURL = try fileOperations.beautifyFilename(for: originalRecord)
        #expect(renamedURL.lastPathComponent == "Shared Two-2.mobileprovision")
        #expect(FileManager.default.fileExists(atPath: renamedURL.path))
    }
}
