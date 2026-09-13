import AppKit
import Foundation
import Testing
@testable import ProfileSmith

@Suite(.serialized)
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
    func detailSelectionDoesNotShiftSplitViewWidthAndLoadsSummary() throws {
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
        #expect(initialWidth >= controller.debugNameColumnMinWidth)

        try controller.debugLoadDetailsSynchronously(for: shortRecord)
        #expect(controller.debugSummaryTextView.string.contains("Short Name"))
        let shortWidth = controller.debugSplitView.arrangedSubviews.first?.frame.width ?? 0

        try controller.debugLoadDetailsSynchronously(for: longRecord)
        #expect(controller.debugSummaryTextView.string.contains("A Very Long Provisioning Profile Name"))
        let longWidth = controller.debugSplitView.arrangedSubviews.first?.frame.width ?? 0

        #expect(abs(initialWidth - shortWidth) < 1)
        #expect(abs(shortWidth - longWidth) < 1)
    }

    @MainActor
    @Test
    func mainWindowShowsBothPanesAfterPreloadingAndResizing() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }
        let context = try AppContext(environment: [
            "PROFILESMITH_SCAN_DIRECTORIES": temporaryDirectory.url.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": temporaryDirectory.url.appendingPathComponent("Support").path,
            "PROFILESMITH_UI_TEST": "1",
        ])
        defer { context.invalidate() }

        let controller = MainViewController(context: context)
        controller.loadViewIfNeeded()
        let splitView = controller.debugSplitView
        splitView.autosaveName = nil
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 840),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }

        for width: CGFloat in [1320, 1100, 1560, 1320] {
            window.setContentSize(NSSize(width: width, height: 840))
            controller.view.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            #expect(splitView.arrangedSubviews[0].frame.width >= controller.debugNameColumnMinWidth)
            #expect(splitView.arrangedSubviews[1].frame.width >= 540)
            #expect(controller.debugTableView.visibleRect.width > 0)
        }

        // 模拟旧版本恢复了折叠状态，再次布局时应自动恢复列表。
        splitView.delegate = nil
        splitView.setPosition(0, ofDividerAt: 0)
        splitView.delegate = controller
        controller.viewDidLayout()
        controller.view.layoutSubtreeIfNeeded()
        #expect(splitView.arrangedSubviews[0].frame.width >= controller.debugNameColumnMinWidth)
        #expect(splitView.arrangedSubviews[1].frame.width >= 540)
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
    func mainTableSupportsCopyingSelectedRows() throws {
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

    }

    @MainActor
    @Test
    func externalOpenRevealsExistingOrImportedProfilesAndScrollsSelectionIntoView() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let scanDirectory = try temporaryDirectory.makeDirectory(named: "Profiles")
        let inboxDirectory = try temporaryDirectory.makeDirectory(named: "Inbox")
        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": scanDirectory.path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
            "PROFILESMITH_UI_TEST": "1",
        ]

        var existingProfileURLs: [URL] = []
        for index in 0..<8 {
            let url = try TestFixtureFactory.writeProfile(
                to: scanDirectory,
                fileName: String(format: "filler-%02d", index),
                name: String(format: "Filler %02d", index),
                uuid: String(format: "FILLER-%02d-AAAA-BBBB-CCCC", index),
                teamName: "Scroll Team",
                teamIdentifier: "SCROLL1234",
                bundleIdentifier: String(format: "com.example.filler.%02d", index)
            )
            existingProfileURLs.append(url)
        }

        let existingURL = try TestFixtureFactory.writeProfile(
            to: scanDirectory,
            fileName: "existing-target",
            name: "Existing Target",
            uuid: "EXISTING-TARGET-AAAA-BBBB-CCCC",
            teamName: "Scroll Team",
            teamIdentifier: "SCROLL1234",
            bundleIdentifier: "com.example.existing"
        )
        existingProfileURLs.append(existingURL)
        let importedSourceURL = try TestFixtureFactory.writeProfile(
            to: inboxDirectory,
            fileName: "zzz-imported",
            name: "ZZZ Imported",
            uuid: "IMPORTED-TARGET-AAAA-BBBB-CCCC",
            teamName: "Scroll Team",
            teamIdentifier: "SCROLL1234",
            bundleIdentifier: "com.example.imported"
        )
        let expectedImportedURL = scanDirectory
            .appendingPathComponent("IMPORTED-TARGET-AAAA-BBBB-CCCC", isDirectory: false)
            .appendingPathExtension("mobileprovision")

        let context = try AppContext(bundle: .main, environment: environment)
        defer { context.invalidate() }

        let controller = MainViewController(context: context)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 280),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        controller.loadViewIfNeeded()
        window.makeKeyAndOrderFront(nil)

        let parser = MobileProvisionParser()
        let sourceLocation = ScanLocation(kind: .custom, url: scanDirectory, displayName: "Profiles")
        let existingRecords = try existingProfileURLs.map { url in
            try parser.parseProfile(at: url, sourceLocation: sourceLocation).record
        }
        controller.debugApplySnapshot(
            RepositorySnapshot(
                profiles: existingRecords,
                metrics: ProfileMetrics(totalCount: existingRecords.count, expiredCount: 0, expiringSoonCount: 0),
                query: ProfileQuery(),
                lastRefreshDate: Date()
            )
        )

        controller.handleExternalFiles([existingURL])
        try waitUntil(
            timeout: 8,
            description: "existing profile was selected from external open",
            debugState: { "selection=\(controller.debugSelectedProfilePaths)" }
        ) {
            controller.debugSelectedProfilePaths == [existingURL.path]
        }

        controller.handleExternalFiles([importedSourceURL])
        try waitUntil(
            timeout: 8,
            description: "imported profile file exists after external open"
        ) {
            FileManager.default.fileExists(atPath: expectedImportedURL.path)
        }

        let importedRecord = try parser.parseProfile(at: expectedImportedURL, sourceLocation: sourceLocation).record
        controller.debugApplySnapshot(
            RepositorySnapshot(
                profiles: existingRecords + [importedRecord],
                metrics: ProfileMetrics(totalCount: existingRecords.count + 1, expiredCount: 0, expiringSoonCount: 0),
                query: ProfileQuery(),
                lastRefreshDate: Date()
            )
        )

        try waitUntil(
            timeout: 8,
            description: "imported profile was selected from external open",
            debugState: {
                "selection=\(controller.debugSelectedProfilePaths) rows=\(controller.debugTableView.numberOfRows)"
            }
        ) {
            controller.debugSelectedProfilePaths == [expectedImportedURL.path]
        }

        try waitUntil(
            timeout: 8,
            description: "selected imported profile row requested scroll into view",
            debugState: {
                "selectedRow=\(controller.debugTableView.selectedRow) requestedRow=\(String(describing: controller.debugLastRequestedVisibleRow))"
            }
        ) {
            controller.debugLastRequestedVisibleRow == controller.debugTableView.selectedRow
        }
    }

    @MainActor
    @Test
    func tableColumnsIncludePlatformAndHeaderSortCanReverseNameAndBundleOrder() throws {
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

        let alphaRecord = TestFixtureFactory.makeRecord(
            path: "/tmp/alpha.mobileprovision",
            name: "Alpha",
            teamName: "Sort Team",
            bundleIdentifier: "com.example.alpha",
            profileType: "Development",
            profilePlatform: "iOS",
            isExpired: false,
            daysUntilExpiration: 50,
            expirationDate: 1_900_000_000
        )
        let betaRecord = TestFixtureFactory.makeRecord(
            path: "/tmp/beta.mobileprovision",
            name: "Beta",
            teamName: "Sort Team",
            bundleIdentifier: "com.example.zeta",
            profileType: "Distribution (App Store)",
            profilePlatform: "Mac",
            isExpired: false,
            daysUntilExpiration: 50,
            expirationDate: 1_900_000_100
        )

        let controller = MainViewController(context: context)
        controller.loadViewIfNeeded()
        controller.debugApplySnapshot(
            RepositorySnapshot(
                profiles: [betaRecord, alphaRecord],
                metrics: ProfileMetrics(totalCount: 2, expiredCount: 0, expiringSoonCount: 0),
                query: ProfileQuery(),
                lastRefreshDate: Date()
            )
        )

        #expect(controller.debugTableView.tableColumns.map(\.identifier.rawValue).contains("platform"))
        #expect(controller.debugTableView.tableColumns.last?.title == "状态")
        #expect(abs(controller.splitView(controller.debugSplitView, constrainMinCoordinate: 0, ofSubviewAt: 0) - controller.debugNameColumnMinWidth) < 0.1)

        controller.debugTableView.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        controller.tableView(controller.debugTableView, sortDescriptorsDidChange: [])
        #expect(controller.debugCurrentProfilePaths == [alphaRecord.path, betaRecord.path])

        controller.debugTableView.sortDescriptors = [NSSortDescriptor(key: "name", ascending: false)]
        controller.tableView(controller.debugTableView, sortDescriptorsDidChange: [])
        #expect(controller.debugCurrentProfilePaths == [betaRecord.path, alphaRecord.path])

        controller.debugTableView.sortDescriptors = [NSSortDescriptor(key: "bundle", ascending: false)]
        controller.tableView(controller.debugTableView, sortDescriptorsDidChange: [])
        #expect(controller.debugCurrentProfilePaths == [betaRecord.path, alphaRecord.path])
    }

    @MainActor
    @Test
    func statusColumnRecalculatesRemainingDaysFromExpirationDate() throws {
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

        let expirationDate = Date().addingTimeInterval((25 * 86_400) + 3_600)
        let record = TestFixtureFactory.makeRecord(
            path: "/tmp/status-recalc.mobileprovision",
            name: "Status Recalc",
            teamName: "Status Team",
            bundleIdentifier: "com.example.status.recalc",
            profileType: "Development",
            profilePlatform: "iOS",
            isExpired: false,
            daysUntilExpiration: 28,
            expirationDate: expirationDate.timeIntervalSince1970
        )

        let controller = MainViewController(context: context)
        controller.loadViewIfNeeded()
        controller.debugApplySnapshot(
            RepositorySnapshot(
                profiles: [record],
                metrics: ProfileMetrics(totalCount: 1, expiredCount: 0, expiringSoonCount: 1),
                query: ProfileQuery(),
                lastRefreshDate: Date()
            )
        )

        let statusColumn = try #require(controller.debugTableView.tableColumns.first(where: { $0.identifier.rawValue == "status" }))
        let statusCell = try #require(controller.tableView(controller.debugTableView, viewFor: statusColumn, row: 0) as? NSTableCellView)
        let expectedDays = MobileProvisionParser.daysUntilExpiration(for: expirationDate)
        #expect(statusCell.textField?.stringValue == "\(expectedDays) 天内到期")
    }

    @MainActor
    @Test
    func visibleTypeAndStatusCellsRefreshWhenLanguageChanges() throws {
        let originalLanguage = AppLocalization.shared.language
        defer {
            AppLocalization.shared.setLanguage(originalLanguage)
        }

        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let supportDirectory = try temporaryDirectory.makeDirectory(named: "Support")
        let environment = [
            "PROFILESMITH_SCAN_DIRECTORIES": temporaryDirectory.url.appendingPathComponent("Profiles", isDirectory: true).path,
            "PROFILESMITH_SUPPORT_DIRECTORY": supportDirectory.path,
            "PROFILESMITH_UI_TEST": "1",
        ]

        AppLocalization.shared.setLanguage(.simplifiedChinese)

        let context = try AppContext(bundle: .main, environment: environment)
        defer { context.invalidate() }

        let expirationDate = Date().addingTimeInterval((12 * 86_400) + 1_800)
        let record = TestFixtureFactory.makeRecord(
            path: "/tmp/runtime-language.mobileprovision",
            name: "Runtime Language",
            teamName: "Runtime Team",
            bundleIdentifier: "com.example.runtime.language",
            profileType: "Development",
            profilePlatform: "iOS",
            isExpired: false,
            daysUntilExpiration: 20,
            expirationDate: expirationDate.timeIntervalSince1970
        )

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
        controller.debugApplySnapshot(
            RepositorySnapshot(
                profiles: [record],
                metrics: ProfileMetrics(totalCount: 1, expiredCount: 0, expiringSoonCount: 1),
                query: ProfileQuery(),
                lastRefreshDate: Date()
            )
        )

        let initialReloadCount = controller.debugLocalizationTableReloadCount
        let typeColumn = try #require(controller.debugTableView.tableColumns.first(where: { $0.identifier.rawValue == "type" }))
        let statusColumn = try #require(controller.debugTableView.tableColumns.first(where: { $0.identifier.rawValue == "status" }))
        let initialTypeCell = try #require(controller.tableView(controller.debugTableView, viewFor: typeColumn, row: 0) as? NSTableCellView)
        let initialStatusCell = try #require(controller.tableView(controller.debugTableView, viewFor: statusColumn, row: 0) as? NSTableCellView)

        #expect(initialTypeCell.textField?.stringValue == L10n.localizedProfileType(record.profileType))
        #expect(initialStatusCell.textField?.stringValue == record.statusText)

        AppLocalization.shared.setLanguage(.english)

        let expectedType = L10n.localizedProfileType(record.profileType)
        let expectedStatus = record.statusText
        try waitUntil(
            description: "row localization updated after runtime language switch",
            debugState: {
                [
                    "reloads=\(controller.debugLocalizationTableReloadCount)",
                    (controller.tableView(controller.debugTableView, viewFor: typeColumn, row: 0) as? NSTableCellView)?.textField?.stringValue ?? "<nil>",
                    (controller.tableView(controller.debugTableView, viewFor: statusColumn, row: 0) as? NSTableCellView)?.textField?.stringValue ?? "<nil>",
                ].joined(separator: " | ")
            }
        ) {
            controller.debugLocalizationTableReloadCount > initialReloadCount
                && (controller.tableView(controller.debugTableView, viewFor: typeColumn, row: 0) as? NSTableCellView)?.textField?.stringValue == expectedType
                && (controller.tableView(controller.debugTableView, viewFor: statusColumn, row: 0) as? NSTableCellView)?.textField?.stringValue == expectedStatus
        }
    }

    @MainActor
    @Test
    func mainViewReappliesResolvedBackgroundColorsWhenAppearanceChanges() throws {
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

        window.appearance = NSAppearance(named: .darkAqua)
        try waitUntil(
            description: "dark appearance applied to main view backgrounds",
            debugState: {
                "main=\(String(describing: controller.debugMainBackgroundColor)) overlay=\(String(describing: controller.debugLoadingOverlayBackgroundColor))"
            }
        ) {
            colorsMatch(controller.debugMainBackgroundColor, expected: NSColor.windowBackgroundColor, appearance: controller.view.effectiveAppearance)
                && colorsMatch(controller.debugLoadingOverlayBackgroundColor, expected: NSColor.windowBackgroundColor, alpha: 0.72, appearance: controller.view.effectiveAppearance)
        }

        window.appearance = NSAppearance(named: .aqua)
        try waitUntil(
            description: "light appearance applied to main view backgrounds",
            debugState: {
                "main=\(String(describing: controller.debugMainBackgroundColor)) overlay=\(String(describing: controller.debugLoadingOverlayBackgroundColor))"
            }
        ) {
            colorsMatch(controller.debugMainBackgroundColor, expected: NSColor.windowBackgroundColor, appearance: controller.view.effectiveAppearance)
                && colorsMatch(controller.debugLoadingOverlayBackgroundColor, expected: NSColor.windowBackgroundColor, alpha: 0.72, appearance: controller.view.effectiveAppearance)
        }
    }

}

private func colorsMatch(_ actual: NSColor?, expected: NSColor, alpha: CGFloat = 1, appearance: NSAppearance) -> Bool {
    guard let actual = actual?.usingColorSpace(.deviceRGB) else { return false }
    var resolved: NSColor?
    appearance.performAsCurrentDrawingAppearance {
        resolved = expected.withAlphaComponent(alpha).usingColorSpace(.deviceRGB)
    }
    guard let resolved else { return false }

    return abs(actual.redComponent - resolved.redComponent) < 0.01
        && abs(actual.greenComponent - resolved.greenComponent) < 0.01
        && abs(actual.blueComponent - resolved.blueComponent) < 0.01
        && abs(actual.alphaComponent - resolved.alphaComponent) < 0.01
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
