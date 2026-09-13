import Foundation
import Testing
@testable import ProfileSmith

struct ArchiveAndFileOperationsTests {
    @Test
    func archiveInspectorReadsAppBundleAndIPA() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let embeddedProfileURL = try TestFixtureFactory.writeProfile(
            to: temporaryDirectory.url,
            fileName: "embedded",
            name: "Embedded Profile",
            uuid: "ARCHIVE-AAAA-BBBB-CCCC-DDDD",
            teamName: "Archive Team",
            teamIdentifier: "ARCH1234",
            bundleIdentifier: "com.example.archive"
        )
        let appURL = try TestFixtureFactory.writeApplicationBundle(
            to: temporaryDirectory.url,
            appName: "ArchiveApp",
            displayName: "Archive App",
            bundleIdentifier: "com.example.archive",
            embeddedProfileURL: embeddedProfileURL
        )
        let ipaURL = try TestFixtureFactory.writeIPA(
            to: temporaryDirectory.url,
            name: "ArchivePayload",
            appDisplayName: "Archive Payload",
            bundleIdentifier: "com.example.payload",
            embeddedProfileURL: embeddedProfileURL
        )

        let inspector = ArchiveInspector(parser: MobileProvisionParser())

        let appInspection = try inspector.inspect(url: appURL)
        #expect(appInspection.title == "Archive App")
        #expect(appInspection.infoPlist?["CFBundleIdentifier"] as? String == "com.example.archive")
        #expect(appInspection.parsedProfile?.record.bundleIdentifier == "com.example.archive")

        let ipaInspection = try inspector.inspect(url: ipaURL)
        #expect(ipaInspection.title == "Archive Payload")
        #expect(ipaInspection.parsedProfile?.record.displayName == "Embedded Profile")
        #expect(ipaInspection.quickLookHTML.contains("Archive Payload"))
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
