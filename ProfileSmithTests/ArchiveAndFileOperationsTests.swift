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

        // 使用自定义支持目录时，重命名备份必须落在该目录下，不能写进用户真实的 ~/Library/MobileDevice。
        #expect(paths.renameBackupDirectory.path.hasPrefix(supportDirectory.path))
        let backups = try FileManager.default.contentsOfDirectory(atPath: paths.renameBackupDirectory.path)
        #expect(backups.count == 1)
        #expect(backups.first?.hasPrefix("Shared Two-") == true)
    }

    @Test
    func importCreatesMissingInstallDirectoryAndSkipsIdenticalFiles() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let missingScanDirectory = temporaryDirectory.url.appendingPathComponent("Not Yet Created", isDirectory: true)
        let paths = try ProfileSupportPaths(bundle: .main, environment: [
            "PROFILESMITH_SCAN_DIRECTORIES": missingScanDirectory.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": try temporaryDirectory.makeDirectory(named: "Support").path,
        ])
        let fileOperations = ProfileFileOperations(paths: paths, parser: MobileProvisionParser())
        let sourceURL = try TestFixtureFactory.writeProfile(
            to: try temporaryDirectory.makeDirectory(named: "Imports"),
            fileName: "incoming",
            name: "Incoming",
            uuid: "IMPORT-AAAA-BBBB",
            teamName: "Import Team",
            teamIdentifier: "IMPT1234",
            bundleIdentifier: "com.example.incoming"
        )

        let firstResult = try fileOperations.importProfiles(from: [sourceURL])
        #expect(firstResult.installedURLs.map(\.lastPathComponent) == ["IMPORT-AAAA-BBBB.mobileprovision"])
        #expect(FileManager.default.fileExists(atPath: missingScanDirectory.path))

        // 重复导入同一份内容应跳过，而不是生成 -2 副本。
        let secondResult = try fileOperations.importProfiles(from: [sourceURL])
        #expect(secondResult.installedURLs.isEmpty)
        #expect(secondResult.skippedURLs.map(\.lastPathComponent) == ["IMPORT-AAAA-BBBB.mobileprovision"])

        // 不支持的文件类型直接忽略。
        let ignored = try fileOperations.importProfiles(from: [URL(fileURLWithPath: "/tmp/not-a-profile.txt")])
        #expect(ignored.installedURLs.isEmpty && ignored.skippedURLs.isEmpty)
    }

    @Test
    func exportingProfileOntoItselfKeepsTheSourceFile() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let paths = try ProfileSupportPaths(bundle: .main, environment: [
            "PROFILESMITH_SCAN_DIRECTORIES": try temporaryDirectory.makeDirectory(named: "Scan").path,
            "PROFILESMITH_SUPPORT_DIRECTORY": try temporaryDirectory.makeDirectory(named: "Support").path,
        ])
        let fileOperations = ProfileFileOperations(paths: paths, parser: MobileProvisionParser())
        let sourceURL = try TestFixtureFactory.writeProfile(
            to: temporaryDirectory.url,
            fileName: "self-export",
            name: "Self Export",
            uuid: "EXPORT-AAAA-BBBB",
            teamName: "Export Team",
            teamIdentifier: "EXPT1234",
            bundleIdentifier: "com.example.export"
        )
        let originalData = try Data(contentsOf: sourceURL)

        try fileOperations.exportProfile(from: sourceURL, to: sourceURL)
        #expect(try Data(contentsOf: sourceURL) == originalData)

        let exportURL = temporaryDirectory.url.appendingPathComponent("exported.mobileprovision")
        try Data("old".utf8).write(to: exportURL)
        try fileOperations.exportProfile(from: sourceURL, to: exportURL)
        #expect(try Data(contentsOf: exportURL) == originalData)
    }

    @Test
    func archiveInspectorHandlesIPAWithoutEmbeddedProfileAndRejectsInvalidArchives() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let ipaURL = try TestFixtureFactory.writeIPA(
            to: temporaryDirectory.url,
            name: "NoProfile",
            appDisplayName: "No Profile App",
            bundleIdentifier: "com.example.noprofile",
            embeddedProfileURL: nil
        )
        let inspector = ArchiveInspector(parser: MobileProvisionParser())

        let inspection = try inspector.inspect(url: ipaURL)
        #expect(inspection.title == "No Profile App")
        #expect(inspection.parsedProfile == nil)
        #expect(inspection.infoPlist?["CFBundleIdentifier"] as? String == "com.example.noprofile")

        let bogusIPA = temporaryDirectory.url.appendingPathComponent("bogus.ipa")
        try Data("not a zip".utf8).write(to: bogusIPA)
        #expect(throws: ParserError.self) {
            _ = try inspector.inspect(url: bogusIPA)
        }

        #expect(throws: ParserError.self) {
            _ = try inspector.inspect(url: temporaryDirectory.url.appendingPathComponent("file.txt"))
        }
    }

    @Test
    func archiveInspectorReadsXCArchiveProducts() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let embeddedProfileURL = try TestFixtureFactory.writeProfile(
            to: temporaryDirectory.url,
            fileName: "archive-embedded",
            name: "XCArchive Profile",
            uuid: "XCARCHIVE-AAAA-BBBB",
            teamName: "Archive Team",
            teamIdentifier: "ARCH1234",
            bundleIdentifier: "com.example.xcarchive"
        )
        let archiveURL = temporaryDirectory.url.appendingPathComponent("Sample.xcarchive", isDirectory: true)
        let applicationsDirectory = archiveURL
            .appendingPathComponent("Products", isDirectory: true)
            .appendingPathComponent("Applications", isDirectory: true)
        try FileManager.default.createDirectory(at: applicationsDirectory, withIntermediateDirectories: true)
        _ = try TestFixtureFactory.writeApplicationBundle(
            to: applicationsDirectory,
            appName: "ArchivedApp",
            displayName: "Archived App",
            bundleIdentifier: "com.example.xcarchive",
            embeddedProfileURL: embeddedProfileURL
        )

        let inspection = try ArchiveInspector(parser: MobileProvisionParser()).inspect(url: archiveURL)
        #expect(inspection.sourceURL == archiveURL)
        #expect(inspection.title == "Archived App")
        #expect(inspection.parsedProfile?.record.displayName == "XCArchive Profile")
    }
}
