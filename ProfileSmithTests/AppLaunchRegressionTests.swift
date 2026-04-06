import AppKit
import Foundation
import Testing
@testable import ProfileSmith

struct AppLaunchRegressionTests {
    @MainActor
    @Test
    func mainWindowControllerShowsAVisibleWindow() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let scanDirectory = temporaryDirectory.url.appendingPathComponent("Missing Scan", isDirectory: true)
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": scanDirectory.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
            "PROFILESMITH_UI_TEST": "1",
        ]

        let context = try AppContext(bundle: .main, environment: environment)
        defer { context.invalidate() }

        let controller = MainWindowController(context: context)
        controller.showWindow(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        let window = try #require(controller.window)
        #expect(window.isVisible)
        #expect(NSApp.windows.contains(window))
    }

    @Test
    func customScanDirectoriesAreNotCreatedDuringLaunchPreparation() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let missingScanDirectory = temporaryDirectory.url
            .appendingPathComponent("Nested", isDirectory: true)
            .appendingPathComponent("Provisioning Profiles", isDirectory: true)
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": missingScanDirectory.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
        ]

        _ = try ProfileSupportPaths(bundle: .main, environment: environment)

        #expect(!FileManager.default.fileExists(atPath: missingScanDirectory.path))
        #expect(FileManager.default.fileExists(atPath: supportDirectory.path))
    }

    @Test
    func quickLookPathsUseEmbeddedProfileSmithExtensionNames() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
        ]

        let paths = try ProfileSupportPaths(bundle: .main, environment: environment)

        #expect(paths.embeddedQuickLookPreviewExtensionURL.lastPathComponent == "ProfileSmithQuickLookPreview.appex")
    }

    @Test
    func appInfoDeclaresProvisioningProfileDocumentTypes() throws {
        let documentTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleDocumentTypes") as? [[String: Any]] ?? []
        let declaredContentTypes = documentTypes
            .flatMap { $0["LSItemContentTypes"] as? [String] ?? [] }

        #expect(declaredContentTypes.contains("com.apple.mobileprovision"))
        #expect(declaredContentTypes.contains("com.apple.iphone.mobileprovision"))
        #expect(declaredContentTypes.contains("com.apple.provisionprofile"))
    }
}
