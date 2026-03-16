import AppKit
import Foundation
import Testing
@testable import ProfileSmith

struct MainViewControllerTests {
    @MainActor
    @Test
    func mainViewControllerLoadsProfilesSearchesAndUpdatesDetails() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let scanDirectory = try temporaryDirectory.makeDirectory(named: "Profiles")
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": scanDirectory.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
            "PROFILESMITH_UI_TEST": "1",
        ]

        _ = try TestFixtureFactory.writeProfile(
            to: scanDirectory,
            fileName: "alpha-dev",
            name: "Alpha Dev",
            uuid: "VIEW-ALPHA-AAAA-BBBB-CCCC",
            teamName: "Alpha Team",
            teamIdentifier: "ALPHA1234",
            bundleIdentifier: "com.example.alpha",
            profileType: "development",
            platform: "iOS",
            expirationDate: Date(timeIntervalSince1970: 1_900_000_000)
        )
        _ = try TestFixtureFactory.writeProfile(
            to: scanDirectory,
            fileName: "beta-mac",
            name: "Beta Mac Store",
            uuid: "VIEW-BETA-AAAA-BBBB-CCCC",
            teamName: "Beta Team",
            teamIdentifier: "BETA1234",
            bundleIdentifier: "com.example.beta.mac",
            profileType: "distribution",
            platform: "Mac",
            expirationDate: Date(timeIntervalSince1970: 1_650_000_000)
        )

        let context = try AppContext(bundle: .main, environment: environment)
        defer { context.invalidate() }

        let parser = MobileProvisionParser()
        let alphaRecord = try parser.parseProfile(
            at: scanDirectory.appendingPathComponent("alpha-dev.mobileprovision"),
            sourceLocation: ScanLocation(kind: .custom, url: scanDirectory, displayName: "Tests")
        ).record
        let betaRecord = try parser.parseProfile(
            at: scanDirectory.appendingPathComponent("beta-mac.provisionprofile"),
            sourceLocation: ScanLocation(kind: .custom, url: scanDirectory, displayName: "Tests")
        ).record

        let controller = MainViewController(context: context)
        controller.loadViewIfNeeded()
        controller.debugApplySnapshot(
            RepositorySnapshot(
                profiles: [alphaRecord, betaRecord],
                metrics: ProfileMetrics(totalCount: 2, expiredCount: 1, expiringSoonCount: 0),
                query: ProfileQuery(),
                lastRefreshDate: Date()
            )
        )

        try waitUntil(
            description: "initial rows",
            debugState: { "rows=\(controller.debugTableView.numberOfRows)" }
        ) {
            controller.debugTableView.numberOfRows == 2
        }

        try controller.debugLoadDetailsSynchronously(for: alphaRecord)

        #expect(controller.debugTitleLabel.stringValue == "Alpha Dev")

        #expect(controller.debugStatusLabel.stringValue.contains("总计 2 条"))

        controller.debugApplySnapshot(
            RepositorySnapshot(
                profiles: [betaRecord],
                metrics: ProfileMetrics(totalCount: 2, expiredCount: 1, expiringSoonCount: 0),
                query: ProfileQuery(searchText: "beta", filter: .all, sort: .expirationAscending),
                lastRefreshDate: Date()
            )
        )

        try waitUntil(
            description: "filtered rows",
            debugState: { "rows=\(controller.debugTableView.numberOfRows) status=\(controller.debugStatusLabel.stringValue)" }
        ) {
            controller.debugTableView.numberOfRows == 1
        }

        #expect(controller.debugStatusLabel.stringValue.contains("当前结果 1 条"))
    }

    @MainActor
    @Test
    func detailSelectionDoesNotShiftSplitViewWidthAndPreviewCompletesRendering() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let scanDirectory = try temporaryDirectory.makeDirectory(named: "Profiles")
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": scanDirectory.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
            "PROFILESMITH_UI_TEST": "1",
        ]

        _ = try TestFixtureFactory.writeProfile(
            to: scanDirectory,
            fileName: "short-name",
            name: "Short Name",
            uuid: "WIDTH-SHORT-AAAA-BBBB-CCCC",
            teamName: "Width Team",
            teamIdentifier: "WIDTH1234",
            bundleIdentifier: "com.example.width.short"
        )
        _ = try TestFixtureFactory.writeProfile(
            to: scanDirectory,
            fileName: "very-long-descriptive-profile-file-name-for-layout-regression-checks",
            name: "A Very Long Provisioning Profile Name Used To Verify The Split View Divider Stays Stable",
            uuid: "WIDTH-LONG-AAAA-BBBB-CCCC",
            teamName: "Width Team",
            teamIdentifier: "WIDTH1234",
            bundleIdentifier: "com.example.width.long.profile.layout"
        )

        let context = try AppContext(bundle: .main, environment: environment)
        defer { context.invalidate() }

        let parser = MobileProvisionParser()
        let shortRecord = try parser.parseProfile(
            at: scanDirectory.appendingPathComponent("short-name.mobileprovision"),
            sourceLocation: ScanLocation(kind: .custom, url: scanDirectory, displayName: "Tests")
        ).record
        let longRecord = try parser.parseProfile(
            at: scanDirectory.appendingPathComponent("very-long-descriptive-profile-file-name-for-layout-regression-checks.mobileprovision"),
            sourceLocation: ScanLocation(kind: .custom, url: scanDirectory, displayName: "Tests")
        ).record

        let controller = MainViewController(context: context)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1380, height: 860),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)
        controller.loadViewIfNeeded()
        controller.debugApplySnapshot(
            RepositorySnapshot(
                profiles: [shortRecord, longRecord],
                metrics: ProfileMetrics(totalCount: 2, expiredCount: 0, expiringSoonCount: 0),
                query: ProfileQuery(),
                lastRefreshDate: Date()
            )
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))

        let initialWidth = controller.debugSplitView.arrangedSubviews.first?.frame.width ?? 0

        try controller.debugLoadDetailsSynchronously(for: shortRecord)
        #expect(controller.debugPreviewText.contains("Short Name"))
        let shortWidth = controller.debugSplitView.arrangedSubviews.first?.frame.width ?? 0

        try controller.debugLoadDetailsSynchronously(for: longRecord)
        #expect(controller.debugPreviewText.contains("A Very Long Provisioning Profile Name"))
        let longWidth = controller.debugSplitView.arrangedSubviews.first?.frame.width ?? 0

        #expect(abs(initialWidth - shortWidth) < 1)
        #expect(abs(shortWidth - longWidth) < 1)
    }

    @MainActor
    @Test
    func profilesTableColumnsRemainUserResizableAndRefreshIndicatorStops() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let scanDirectory = try temporaryDirectory.makeDirectory(named: "Profiles")
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": scanDirectory.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
            "PROFILESMITH_UI_TEST": "1",
        ]

        let context = try AppContext(bundle: .main, environment: environment)
        defer { context.invalidate() }

        let controller = MainViewController(context: context)
        controller.loadViewIfNeeded()

        #expect(controller.debugSplitView.arrangedSubviews.count == 2)
        #expect(controller.debugSplitView.arrangedSubviews.allSatisfy { $0.translatesAutoresizingMaskIntoConstraints == false })
        #expect(controller.debugTableView.columnAutoresizingStyle == .noColumnAutoresizing)
        #expect(controller.debugTableView.tableColumns.count >= 3)
        #expect(controller.debugTableView.tableColumns[0].resizingMask.contains(.userResizingMask))
        #expect(controller.debugTableView.tableColumns[1].resizingMask.contains(.userResizingMask))
        #expect(controller.debugTableView.tableColumns[2].resizingMask.contains(.userResizingMask))

        controller.debugApplyRepositoryRefreshState(true)
        #expect(controller.debugProgressIndicator.isHidden == false)

        controller.debugApplyRepositoryRefreshState(false)
        #expect(controller.debugProgressIndicator.isHidden)
    }

    @MainActor
    @Test
    func coldLaunchViewAppearanceResyncsStaleRefreshIndicatorWithoutManualRefresh() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": temporaryDirectory.url.appendingPathComponent("Profiles", isDirectory: true).path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
            "PROFILESMITH_UI_TEST": "1",
        ]

        let context = try AppContext(bundle: .main, environment: environment)
        defer { context.invalidate() }
        context.repository.debugSetRefreshState(false)

        let controller = MainViewController(context: context)
        controller.loadViewIfNeeded()
        controller.debugApplyRepositoryRefreshState(true)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 840),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)

        try waitUntil(
            description: "view appearance resynced stale refresh indicator",
            debugState: {
                "refreshing=\(context.repository.isRefreshing) hidden=\(controller.debugProgressIndicator.isHidden)"
            }
        ) {
            controller.debugProgressIndicator.isHidden
        }
    }

    @MainActor
    @Test
    func repositoryRefreshPublisherStopsProgressIndicatorAfterControllerBinds() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": temporaryDirectory.url.appendingPathComponent("Profiles", isDirectory: true).path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
            "PROFILESMITH_UI_TEST": "1",
        ]

        let context = try AppContext(bundle: .main, environment: environment)
        defer { context.invalidate() }

        let controller = MainViewController(context: context)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 840),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        controller.loadViewIfNeeded()
        window.makeKeyAndOrderFront(nil)

        context.repository.debugSetRefreshState(true)
        try waitUntil(
            description: "repository publisher showed refresh indicator after controller binding",
            debugState: {
                "refreshing=\(context.repository.isRefreshing) hidden=\(controller.debugProgressIndicator.isHidden)"
            }
        ) {
            context.repository.isRefreshing && controller.debugProgressIndicator.isHidden == false
        }

        context.repository.debugSetRefreshState(false)
        try waitUntil(
            description: "repository publisher hid refresh indicator after controller binding",
            debugState: {
                "refreshing=\(context.repository.isRefreshing) hidden=\(controller.debugProgressIndicator.isHidden)"
            }
        ) {
            context.repository.isRefreshing == false && controller.debugProgressIndicator.isHidden
        }
    }

    @MainActor
    @Test
    func previewWindowControllerLoadsProfileAndInfoTabs() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let embeddedProfileURL = try TestFixtureFactory.writeProfile(
            to: temporaryDirectory.url,
            fileName: "embedded",
            name: "Embedded Preview",
            uuid: "PREVIEW-AAAA-BBBB-CCCC-DDDD",
            teamName: "Preview Team",
            teamIdentifier: "PREV1234",
            bundleIdentifier: "com.example.preview"
        )
        let appURL = try TestFixtureFactory.writeApplicationBundle(
            to: temporaryDirectory.url,
            appName: "PreviewHost",
            displayName: "Preview Host",
            bundleIdentifier: "com.example.preview.host",
            embeddedProfileURL: embeddedProfileURL
        )

        let inspection = try ArchiveInspector(parser: MobileProvisionParser()).inspect(url: appURL)
        let controller = PreviewWindowController(inspection: inspection)

        #expect(controller.debugTitleLabel.stringValue == "Preview Host")
        #expect(controller.debugOverviewRows.contains(where: { $0.contains("名称: Preview Host") }))
        #expect(controller.debugOverviewRows.contains(where: { $0.contains("描述文件: Embedded Preview") }))

        controller.debugSelectSegment(1)
        #expect(controller.debugProfileOutlineView.numberOfRows > 0)

        controller.debugSelectSegment(2)
        #expect(controller.debugInfoOutlineView.numberOfRows > 0)
    }

    @MainActor
    @Test
    func mainTableAndPreviewWindowSupportCopyingSelectedRows() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let scanDirectory = try temporaryDirectory.makeDirectory(named: "Profiles")
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": scanDirectory.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
            "PROFILESMITH_UI_TEST": "1",
        ]

        let embeddedProfileURL = try TestFixtureFactory.writeProfile(
            to: scanDirectory,
            fileName: "copy-target",
            name: "Copy Ready",
            uuid: "COPY-AAAA-BBBB-CCCC-DDDD",
            teamName: "Copy Team",
            teamIdentifier: "COPY1234",
            bundleIdentifier: "com.example.copy"
        )

        let context = try AppContext(bundle: .main, environment: environment)
        defer { context.invalidate() }

        let parser = MobileProvisionParser()
        let record = try parser.parseProfile(
            at: embeddedProfileURL,
            sourceLocation: ScanLocation(kind: .custom, url: scanDirectory, displayName: "Tests")
        ).record

        let controller = MainViewController(context: context)
        controller.loadViewIfNeeded()
        controller.debugApplySnapshot(
            RepositorySnapshot(
                profiles: [record],
                metrics: ProfileMetrics(totalCount: 1, expiredCount: 0, expiringSoonCount: 0),
                query: ProfileQuery(),
                lastRefreshDate: Date()
            )
        )

        controller.debugTableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        controller.debugTableView.copy(nil)
        let mainCopy = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(mainCopy.contains("Copy Ready"))
        #expect(mainCopy.contains("com.example.copy"))

        let appURL = try TestFixtureFactory.writeApplicationBundle(
            to: temporaryDirectory.url,
            appName: "PreviewCopyHost",
            displayName: "Preview Copy Host",
            bundleIdentifier: "com.example.preview.copy",
            embeddedProfileURL: embeddedProfileURL
        )
        let inspection = try ArchiveInspector(parser: MobileProvisionParser()).inspect(url: appURL)
        let previewController = PreviewWindowController(inspection: inspection)

        previewController.debugSelectOverviewRows(IndexSet(integer: 0))
        previewController.debugCopyOverviewSelection()
        let overviewCopy = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(overviewCopy.contains("文件"))

        previewController.debugSelectSegment(1)
        previewController.debugSelectProfileRows(IndexSet(integer: 0))
        previewController.debugCopyProfileSelection()
        let profileCopy = NSPasteboard.general.string(forType: .string) ?? ""
        #expect(!profileCopy.isEmpty)
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
        throw NSError(domain: "ProfileSmithTests.Timeout", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Condition '\(description)' was not satisfied within \(timeout) seconds. \(debugState())",
        ])
    }
}
