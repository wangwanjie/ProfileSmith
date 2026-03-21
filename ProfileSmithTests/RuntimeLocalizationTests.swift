import AppKit
import Foundation
import Testing
@testable import ProfileSmith

@Suite(.serialized)
struct RuntimeLocalizationTests {
    @MainActor
    @Test
    func mainViewRefreshesWhenLanguageChanges() throws {
        let originalLanguage = AppLocalization.shared.language
        defer {
            AppLocalization.shared.setLanguage(originalLanguage)
        }

        let temporaryDirectory = try TestTemporaryDirectory(prefix: "ProfileSmithRuntimeLocalization")
        defer { temporaryDirectory.cleanup() }

        let scanDirectory = try temporaryDirectory.makeDirectory(named: "Profiles")
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": scanDirectory.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
            "PROFILESMITH_UI_TEST": "1",
        ]

        AppLocalization.shared.setLanguage(.simplifiedChinese)

        let context = try AppContext(bundle: .main, environment: environment)
        defer { context.invalidate() }

        let controller = MainViewController(context: context)
        controller.loadViewIfNeeded()
        controller.debugApplySnapshot(
            RepositorySnapshot(
                profiles: [],
                metrics: ProfileMetrics(totalCount: 2, expiredCount: 1, expiringSoonCount: 1),
                query: ProfileQuery(),
                lastRefreshDate: nil
            )
        )

        let refreshButton: NSButton = try reflectedValue(named: "refreshButton", from: controller)
        let importButton: NSButton = try reflectedValue(named: "importButton", from: controller)
        let searchField: NSSearchField = try reflectedValue(named: "searchField", from: controller)
        let tabControl: NSSegmentedControl = try reflectedValue(named: "tabControl", from: controller)

        #expect(refreshButton.title == "刷新")
        #expect(importButton.title == "导入/预览…")
        #expect(controller.debugSubtitleLabel.stringValue == "拖入描述文件、IPA、XCArchive 或 APPEX，或在左侧选择已有描述文件。")
        #expect(searchField.placeholderString == "全文搜索描述文件内容、Bundle ID、Team、UUID…")
        #expect(tabControl.label(forSegment: 0) == "概要")

        AppLocalization.shared.setLanguage(.english)

        try waitUntil(
            description: "main view localization updated after runtime language switch",
            debugState: {
                return [
                    "refresh=\(refreshButton.title)",
                    "import=\(importButton.title)",
                    "subtitle=\(controller.debugSubtitleLabel.stringValue)",
                    "search=\(searchField.placeholderString ?? "")",
                    "tab0=\(String(describing: tabControl.label(forSegment: 0)))",
                    "status=\(controller.debugStatusLabel.stringValue)",
                ].joined(separator: " | ")
            }
        ) {
            return refreshButton.title == "Refresh"
                && importButton.title == "Import / Preview…"
                && controller.debugSubtitleLabel.stringValue == "Drag in profiles, IPA, XCArchive, or APPEX files, or select an existing profile from the list."
                && searchField.placeholderString == "Search profile contents, Bundle ID, Team, UUID…"
                && tabControl.label(forSegment: 0) == "Overview"
                && controller.debugStatusLabel.stringValue.contains("Results 0")
        }
    }
}

private func reflectedValue<T>(named name: String, from instance: Any) throws -> T {
    for child in Mirror(reflecting: instance).children {
        if child.label == name, let value = child.value as? T {
            return value
        }
    }

    throw NSError(
        domain: "ProfileSmithTests.Reflection",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing reflected value named '\(name)'."]
    )
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
