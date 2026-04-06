import Foundation
import Testing
@testable import ProfileSmith

struct QuickLookPluginManagerTests {
    @Test
    func previewExtensionAloneMakesQuickLookAvailableAndRegistered() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let bundle = try makeTestAppBundle(in: temporaryDirectory, includePreviewExtension: true)
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let paths = try ProfileSupportPaths(
            bundle: bundle,
            environment: ["PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path]
        )

        let manager = QuickLookPluginManager(
            paths: paths,
            commandRunner: { _, _ in "" },
            registeredBundleIdentifiersProvider: {
                [QuickLookPluginManager.previewBundleIdentifier]
            }
        )

        #expect(manager.isAvailable)
        #expect(manager.isRegistered)
    }

    @Test
    func refreshRegistrationAddsAndPromotesPreviewWithoutBuildingThumbnail() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let bundle = try makeTestAppBundle(in: temporaryDirectory, includePreviewExtension: true)
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let paths = try ProfileSupportPaths(
            bundle: bundle,
            environment: ["PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path]
        )

        var commands: [(String, [String])] = []
        let manager = QuickLookPluginManager(
            paths: paths,
            commandRunner: { executable, arguments in
                commands.append((executable, arguments))
                return ""
            },
            registeredBundleIdentifiersProvider: { [] }
        )

        try manager.refreshRegistration()

        #expect(commands.count == 5)
        #expect(commands[0].0 == "/usr/bin/pluginkit")
        #expect(commands[0].1 == ["-a", paths.embeddedQuickLookPreviewExtensionURL.path])
        #expect(commands[1].0 == "/usr/bin/pluginkit")
        #expect(commands[1].1 == ["-e", "use", "-i", QuickLookPluginManager.previewBundleIdentifier])
        #expect(commands[2].0 == "/usr/bin/pluginkit")
        #expect(commands[2].1 == ["-e", "ignore", "-i", QuickLookPluginManager.thumbnailBundleIdentifier])
        #expect(commands[3].1 == ["-r"])
        #expect(commands[4].1 == ["-r", "cache"])
        #expect(commands.allSatisfy { !$0.1.contains(where: { $0.contains("ProfileSmithQuickLookThumbnail.appex") }) })
    }

    private func makeTestAppBundle(
        in temporaryDirectory: TestTemporaryDirectory,
        includePreviewExtension: Bool
    ) throws -> Bundle {
        let appURL = temporaryDirectory.url.appendingPathComponent("ProfileSmithTest.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let plugInsURL = contentsURL.appendingPathComponent("PlugIns", isDirectory: true)

        try FileManager.default.createDirectory(at: plugInsURL, withIntermediateDirectories: true)

        let infoPlist: [String: Any] = [
            "CFBundleIdentifier": "cn.vanjay.ProfileSmithTestsHost",
            "CFBundleName": "ProfileSmithTestsHost",
            "CFBundleExecutable": "ProfileSmithTestsHost",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
        ]
        let infoPlistData = try PropertyListSerialization.data(fromPropertyList: infoPlist, format: .xml, options: 0)
        try infoPlistData.write(to: contentsURL.appendingPathComponent("Info.plist"))

        if includePreviewExtension {
            try FileManager.default.createDirectory(
                at: plugInsURL.appendingPathComponent("ProfileSmithQuickLookPreview.appex", isDirectory: true),
                withIntermediateDirectories: true
            )
        }

        return try #require(Bundle(url: appURL))
    }
}
