import AppKit
import Foundation
import Testing
@testable import ProfileSmith

@Suite(.serialized)
struct PreviewLocalizationTests {
    @MainActor
    @Test
    func previewWindowRefreshesWhenLanguageChanges() throws {
        let originalLanguage = AppLocalization.shared.language
        defer {
            AppLocalization.shared.setLanguage(originalLanguage)
        }

        let temporaryDirectory = try TestTemporaryDirectory(prefix: "ProfileSmithPreviewLocalization")
        defer { temporaryDirectory.cleanup() }

        let embeddedProfileURL = try TestFixtureFactory.writeProfile(
            to: temporaryDirectory.url,
            fileName: "embedded-preview",
            name: "Embedded Preview",
            uuid: "PREVIEW-L10N-AAAA-BBBB-CCCC",
            teamName: "Preview Team",
            teamIdentifier: "PREV1234",
            bundleIdentifier: "com.example.preview.localization"
        )
        let appURL = try TestFixtureFactory.writeApplicationBundle(
            to: temporaryDirectory.url,
            appName: "PreviewLocalizationHost",
            displayName: "Preview Localization Host",
            bundleIdentifier: "com.example.preview.host",
            embeddedProfileURL: embeddedProfileURL
        )

        AppLocalization.shared.setLanguage(.simplifiedChinese)
        let inspection = try ArchiveInspector(parser: MobileProvisionParser()).inspect(url: appURL)
        let controller = PreviewWindowController(inspection: inspection)

        #expect(controller.debugSegmentedControl.label(forSegment: 0) == "总览")
        #expect(controller.debugOverviewRows.contains(where: { $0.hasPrefix("文件:") }))
        #expect(controller.debugOverviewRows.contains(where: { $0.hasPrefix("描述文件:") }))

        AppLocalization.shared.setLanguage(.english)

        try waitUntil(
            description: "preview window localization updated after runtime language switch",
            debugState: {
                [
                    controller.debugSegmentedControl.label(forSegment: 0) ?? "<nil>",
                    controller.debugSegmentedControl.label(forSegment: 1) ?? "<nil>",
                    controller.debugSegmentedControl.label(forSegment: 2) ?? "<nil>",
                    controller.debugOverviewRows.joined(separator: " | "),
                ].joined(separator: " | ")
            }
        ) {
            controller.debugSegmentedControl.label(forSegment: 0) == "Overview"
                && controller.debugSegmentedControl.label(forSegment: 1) == "Profile"
                && controller.debugSegmentedControl.label(forSegment: 2) == "Info.plist"
                && controller.debugOverviewRows.contains(where: { $0.hasPrefix("File:") })
                && controller.debugOverviewRows.contains(where: { $0.hasPrefix("Embedded Profile:") })
        }
    }

    @MainActor
    @Test
    func archiveInspectorHTMLUsesCurrentAppLanguage() throws {
        let originalLanguage = AppLocalization.shared.language
        defer {
            AppLocalization.shared.setLanguage(originalLanguage)
        }

        let temporaryDirectory = try TestTemporaryDirectory(prefix: "ProfileSmithArchiveHTMLLocalization")
        defer { temporaryDirectory.cleanup() }

        let embeddedProfileURL = try TestFixtureFactory.writeProfile(
            to: temporaryDirectory.url,
            fileName: "embedded-html",
            name: "Embedded HTML",
            uuid: "PREVIEW-HTML-AAAA-BBBB-CCCC",
            teamName: "Preview Team",
            teamIdentifier: "PREV1234",
            bundleIdentifier: "com.example.preview.html"
        )
        let appURL = try TestFixtureFactory.writeApplicationBundle(
            to: temporaryDirectory.url,
            appName: "HTMLLocalizationHost",
            displayName: "HTML Localization Host",
            bundleIdentifier: "com.example.preview.html.host",
            embeddedProfileURL: embeddedProfileURL
        )

        AppLocalization.shared.setLanguage(.english)
        let englishInspection = try ArchiveInspector(parser: MobileProvisionParser()).inspect(url: appURL)
        #expect(englishInspection.quickLookHTML.contains(">Overview<"))
        #expect(englishInspection.quickLookHTML.contains("View the profile summary"))
        #expect(englishInspection.quickLookHTML.contains(">Certificates<"))

        AppLocalization.shared.setLanguage(.traditionalChinese)
        let traditionalInspection = try ArchiveInspector(parser: MobileProvisionParser()).inspect(url: appURL)
        #expect(traditionalInspection.quickLookHTML.contains(">概要<"))
        #expect(traditionalInspection.quickLookHTML.contains("在目前視窗中查看描述檔概要"))
        #expect(traditionalInspection.quickLookHTML.contains(">證書<"))
    }
}

@MainActor
private func waitUntil(
    timeout: TimeInterval = 5,
    description: String,
    debugState: @escaping () -> String = { "" },
    condition: @escaping () -> Bool
) throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    if !condition() {
        throw NSError(
            domain: "ProfileSmithTests.Timeout",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Condition '\(description)' was not satisfied within \(timeout) seconds. \(debugState())",
            ]
        )
    }
}
