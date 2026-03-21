import Foundation

enum L10n {
    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalization.shared.string(key, arguments: arguments)
    }

    static var appName: String { tr("app.name") }
    static var fatalLaunchTitle: String { tr("fatal.launch.title") }
    static var cancel: String { tr("common.cancel") }
    static var confirm: String { tr("common.confirm") }
    static var delete: String { tr("common.delete") }
    static var moveToTrash: String { tr("common.move_to_trash") }

    static var menuAbout: String { tr("menu.about") }
    static var menuPreferences: String { tr("menu.preferences") }
    static var menuCheckForUpdates: String { tr("menu.check_updates") }
    static var menuFinderQuickLook: String { tr("menu.finder_quicklook") }
    static var menuHideApp: String { tr("menu.hide_app") }
    static var menuHideOthers: String { tr("menu.hide_others") }
    static var menuShowAll: String { tr("menu.show_all") }
    static var menuQuitApp: String { tr("menu.quit_app") }
    static var menuFile: String { tr("menu.file") }
    static var menuImportProfiles: String { tr("menu.import_profiles") }
    static var menuRefresh: String { tr("menu.refresh") }
    static var menuCloseWindow: String { tr("menu.close_window") }
    static var menuEdit: String { tr("menu.edit") }
    static var menuUndo: String { tr("menu.undo") }
    static var menuRedo: String { tr("menu.redo") }
    static var menuCut: String { tr("menu.cut") }
    static var menuCopy: String { tr("menu.copy") }
    static var menuPaste: String { tr("menu.paste") }
    static var menuSelectAll: String { tr("menu.select_all") }
    static var menuView: String { tr("menu.view") }
    static var menuShowMainWindow: String { tr("menu.show_main_window") }
    static var menuWindow: String { tr("menu.window") }
    static var menuMinimize: String { tr("menu.minimize") }
    static var menuZoom: String { tr("menu.zoom") }
    static var menuHelp: String { tr("menu.help") }
    static var menuGitHubHomepage: String { tr("menu.github_homepage") }

    static var preferencesWindowTitle: String { tr("preferences.window.title") }
    static var preferencesTitle: String { tr("preferences.title") }
    static var preferencesDescription: String { tr("preferences.description") }
    static var preferencesSegmentGeneral: String { tr("preferences.segment.general") }
    static var preferencesSegmentUpdates: String { tr("preferences.segment.updates") }
    static var preferencesLanguage: String { tr("preferences.language") }
    static var preferencesAppearance: String { tr("preferences.appearance") }
    static var preferencesUpdateChecks: String { tr("preferences.update_checks") }
    static var preferencesAutoDownloads: String { tr("preferences.auto_downloads") }
    static var preferencesAutoDownloadsAvailable: String { tr("preferences.auto_downloads.available") }
    static var preferencesAutoDownloadsUnavailable: String { tr("preferences.auto_downloads.unavailable") }
    static var preferencesCheckForUpdates: String { tr("preferences.check_updates") }
    static var preferencesOpenGitHub: String { tr("preferences.open_github") }

    static var quickLookUnavailable: String { tr("quicklook.unavailable") }
    static var quickLookRefresh: String { tr("quicklook.refresh") }
    static var quickLookEnable: String { tr("quicklook.enable") }
    static var quickLookMissingExtensions: String { tr("quicklook.error.missing_extensions") }
    static var quickLookRefreshFailed: String { tr("quicklook.error.refresh_failed") }
    static var quickLookReady: String { tr("quicklook.state.ready") }
    static var quickLookPending: String { tr("quicklook.state.pending") }
    static func quickLookPanelAvailable(_ actionTitle: String) -> String { tr("quicklook.panel.available", actionTitle) }
    static var quickLookPanelUnavailable: String { tr("quicklook.panel.unavailable") }

    static func statusIndexed(_ count: Int) -> String { tr("status.indexed", count) }
    static func statusWarning(expired: Int, expiringSoon: Int) -> String { tr("status.warning", expired, expiringSoon) }
    static var statusOpen: String { tr("status.open") }
    static var statusRefresh: String { tr("status.refresh") }
    static var statusCheckForUpdates: String { tr("status.check_updates") }
    static var statusQuit: String { tr("status.quit") }

    static var mainSearchPlaceholder: String { tr("main.search_placeholder") }
    static var mainRefresh: String { tr("main.refresh") }
    static var mainImportPreview: String { tr("main.import_preview") }
    static var mainLoadingTitle: String { tr("main.loading.title") }
    static var mainLoadingHint: String { tr("main.loading.hint") }
    static var mainEmptySubtitle: String { tr("main.empty.subtitle") }
    static var mainTabOverview: String { tr("main.tab.overview") }
    static var mainTabDetail: String { tr("main.tab.detail") }
    static var mainTabPreview: String { tr("main.tab.preview") }
    static var mainActionPreview: String { tr("main.action.preview") }
    static var mainActionFinder: String { tr("main.action.finder") }
    static var mainActionExport: String { tr("main.action.export") }
    static var mainActionBeautifyFilename: String { tr("main.action.beautify_filename") }
    static var mainActionMoveToTrash: String { tr("main.action.move_to_trash") }
    static var mainActionDeletePermanently: String { tr("main.action.delete_permanently") }
    static var mainColumnName: String { tr("main.column.name") }
    static var mainColumnBundle: String { tr("main.column.bundle") }
    static var mainColumnTeam: String { tr("main.column.team") }
    static var mainColumnPlatform: String { tr("main.column.platform") }
    static var mainColumnType: String { tr("main.column.type") }
    static var mainColumnExpires: String { tr("main.column.expires") }
    static var mainColumnStatus: String { tr("main.column.status") }
    static var mainInspectorKey: String { tr("main.inspector.key") }
    static var mainInspectorType: String { tr("main.inspector.type") }
    static var mainInspectorValue: String { tr("main.inspector.value") }
    static var mainDetailLoading: String { tr("main.detail.loading") }
    static var mainPreviewGeneratingTitle: String { tr("main.preview.generating.title") }
    static var mainPreviewGeneratingMessage: String { tr("main.preview.generating.message") }
    static func mainDetailParseFailed(_ message: String) -> String { tr("main.detail.parse_failed", message) }
    static var mainPreviewFailedTitle: String { tr("main.preview.failed.title") }
    static var mainEmptySummary: String { tr("main.empty.summary") }
    static var mainEmptyPreviewMessage: String { tr("main.empty.preview.message") }
    static func mainBulkTitle(_ count: Int) -> String { tr("main.bulk.title", count) }
    static var mainBulkSubtitle: String { tr("main.bulk.subtitle") }
    static var mainBulkBadge: String { tr("main.bulk.badge") }
    static func mainBulkTeamCount(_ count: Int) -> String { tr("main.bulk.team_count", count) }
    static func mainBulkExpiredCount(_ count: Int) -> String { tr("main.bulk.expired_count", count) }
    static func mainBulkPreviewTitle(_ count: Int) -> String { tr("main.bulk.preview.title", count) }
    static var mainBulkPreviewMessage: String { tr("main.bulk.preview.message") }
    static func mainLastRefresh(_ timestamp: String) -> String { tr("main.status.last_refresh", timestamp) }
    static var mainNeverRefreshed: String { tr("main.status.never_refreshed") }
    static var mainLoadingPrefix: String { tr("main.status.loading_prefix") }
    static func mainStatusSummary(current: Int, total: Int, expired: Int, expiringSoon: Int, refresh: String) -> String {
        tr("main.status.summary", current, total, expired, expiringSoon, refresh)
    }
    static func mainStatusSummarySelected(current: Int, selected: Int, total: Int, expired: Int, expiringSoon: Int, refresh: String) -> String {
        tr("main.status.summary.selected", current, selected, total, expired, expiringSoon, refresh)
    }
    static var mainImportCompletedTitle: String { tr("main.import.completed.title") }
    static func mainImportCompletedBody(installed: Int, skipped: Int) -> String { tr("main.import.completed.body", installed, skipped) }
    static var mainRenameCompleted: String { tr("main.rename.completed") }
    static var mainDeleteToTrashTitle: String { tr("main.delete.to_trash.title") }
    static var mainDeletePermanentlyTitle: String { tr("main.delete.permanently.title") }
    static var mainContextPreview: String { tr("main.context.preview") }
    static var mainContextShowInFinder: String { tr("main.context.show_in_finder") }
    static var mainContextCopyPath: String { tr("main.context.copy_path") }
    static var mainContextCopyRow: String { tr("main.context.copy_row") }
    static var mainContextExportProfile: String { tr("main.context.export_profile") }
    static var mainContextBeautifyFilename: String { tr("main.context.beautify_filename") }
    static var mainContextMoveToTrash: String { tr("main.context.move_to_trash") }
    static var mainContextDeletePermanently: String { tr("main.context.delete_permanently") }
    static var mainContextExportCertificate: String { tr("main.context.export_certificate") }
    static var mainContextCopySHA1: String { tr("main.context.copy_sha1") }
    static var mainContextCopySHA256: String { tr("main.context.copy_sha256") }
    static var mainSummaryBasicInfo: String { tr("main.summary.basic_info") }
    static var mainSummaryName: String { tr("main.summary.name") }
    static var mainSummaryUUID: String { tr("main.summary.uuid") }
    static var mainSummaryBundleID: String { tr("main.summary.bundle_id") }
    static var mainSummaryAppIDName: String { tr("main.summary.app_id_name") }
    static var mainSummaryApplicationIdentifier: String { tr("main.summary.application_identifier") }
    static var mainSummaryTeam: String { tr("main.summary.team") }
    static var mainSummaryTeamIdentifier: String { tr("main.summary.team_identifier") }
    static var mainSummaryPlatform: String { tr("main.summary.platform") }
    static var mainSummaryType: String { tr("main.summary.type") }
    static var mainSummaryCreationDate: String { tr("main.summary.creation_date") }
    static var mainSummaryExpirationDate: String { tr("main.summary.expiration_date") }
    static var mainSummaryRemainingDays: String { tr("main.summary.remaining_days") }
    static var mainSummaryDeviceCount: String { tr("main.summary.device_count") }
    static var mainSummaryCertificateCount: String { tr("main.summary.certificate_count") }
    static var mainSummarySourceDirectory: String { tr("main.summary.source_directory") }
    static var mainSummaryFilePath: String { tr("main.summary.file_path") }
    static var mainSummaryEntitlements: String { tr("main.summary.entitlements") }
    static var mainSummaryCertificates: String { tr("main.summary.certificates") }

    static var updateNotConfigured: String { tr("update.not_configured") }
    static var updateUpToDateTitle: String { tr("update.up_to_date.title") }
    static func updateUpToDateBody(current: String, latest: String) -> String { tr("update.up_to_date.body", current, latest) }
    static func updateAvailableTitle(_ version: String) -> String { tr("update.available.title", version) }
    static var updateAvailableFallback: String { tr("update.available.fallback") }
    static var updateButtonOpenGitHub: String { tr("update.button.open_github") }
    static var updateFailureTitle: String { tr("update.failure.title") }

    static var filterAll: String { tr("filter.all") }
    static var filterExpiringSoon: String { tr("filter.expiring_soon") }
    static var filterExpired: String { tr("filter.expired") }
    static var filterDevelopment: String { tr("filter.development") }
    static var filterDistribution: String { tr("filter.distribution") }
    static var filterEnterprise: String { tr("filter.enterprise") }
    static var filterMac: String { tr("filter.mac") }

    static var sortExpirationAscending: String { tr("sort.expiration_ascending") }
    static var sortExpirationDescending: String { tr("sort.expiration_descending") }
    static var sortNameAscending: String { tr("sort.name_ascending") }
    static var sortTeamAscending: String { tr("sort.team_ascending") }
    static var sortModificationDescending: String { tr("sort.modification_descending") }

    static var profileStatusExpired: String { tr("profile.status.expired") }
    static var profileStatusValid: String { tr("profile.status.valid") }
    static var profileStatusExpiringToday: String { tr("profile.status.expiring_today") }
    static func profileStatusExpiringSoon(_ days: Int) -> String { tr("profile.status.expiring_soon", days) }

    static var displayProfileTypeDevelopment: String { tr("display.profile_type.development") }
    static var displayProfileTypeDistributionAppStore: String { tr("display.profile_type.distribution_app_store") }
    static var displayProfileTypeDistributionAdHoc: String { tr("display.profile_type.distribution_adhoc") }
    static var displayProfileTypeEnterprise: String { tr("display.profile_type.enterprise") }
    static var displayPlatformIOS: String { tr("display.platform.ios") }
    static var displayPlatformMac: String { tr("display.platform.mac") }
    static var displayFileTypeIOSProfile: String { tr("display.file_type.ios_profile") }
    static var displayFileTypeMacProfile: String { tr("display.file_type.mac_profile") }
    static var displayFileTypeFile: String { tr("display.file_type.file") }

    static func parserUnsupportedFile(_ fileName: String) -> String { tr("parser.unsupported_file", fileName) }
    static func parserUnreadableData(_ filePath: String) -> String { tr("parser.unreadable_data", filePath) }
    static func parserMissingEmbeddedPlist(_ fileName: String) -> String { tr("parser.missing_embedded_plist", fileName) }
    static func parserMalformedPropertyList(_ fileName: String) -> String { tr("parser.malformed_property_list", fileName) }
    static func parserMissingApplicationBundle(_ filePath: String) -> String { tr("parser.missing_application_bundle", filePath) }

    static var previewWindowTabOverview: String { tr("preview.window.tab.overview") }
    static var previewWindowTabProfile: String { tr("preview.window.tab.profile") }
    static var previewWindowTabInfoPlist: String { tr("preview.window.tab.info_plist") }
    static var previewWindowCopySelectedRows: String { tr("preview.window.copy_selected_rows") }
    static var previewWindowColumnKey: String { tr("preview.window.column.key") }
    static var previewWindowColumnType: String { tr("preview.window.column.type") }
    static var previewWindowColumnValue: String { tr("preview.window.column.value") }
    static var previewWindowRowFile: String { tr("preview.window.row.file") }
    static var previewWindowRowName: String { tr("preview.window.row.name") }
    static var previewWindowRowBundleID: String { tr("preview.window.row.bundle_id") }
    static var previewWindowRowAppIDName: String { tr("preview.window.row.app_id_name") }
    static var previewWindowRowTeam: String { tr("preview.window.row.team") }
    static var previewWindowRowTeamID: String { tr("preview.window.row.team_id") }
    static var previewWindowRowType: String { tr("preview.window.row.type") }
    static var previewWindowRowPlatform: String { tr("preview.window.row.platform") }
    static var previewWindowRowUUID: String { tr("preview.window.row.uuid") }
    static var previewWindowRowCreated: String { tr("preview.window.row.created") }
    static var previewWindowRowExpires: String { tr("preview.window.row.expires") }
    static var previewWindowRowApplicationID: String { tr("preview.window.row.application_id") }
    static var previewWindowRowCertificates: String { tr("preview.window.row.certificates") }
    static var previewWindowRowDevices: String { tr("preview.window.row.devices") }
    static var previewWindowRowEmbeddedProfile: String { tr("preview.window.row.embedded_profile") }
    static var previewWindowRowInfoPlist: String { tr("preview.window.row.info_plist") }
    static var previewWindowNoEmbeddedProfile: String { tr("preview.window.no_embedded_profile") }
    static var previewWindowAvailabilityAvailable: String { tr("preview.window.availability.available") }
    static var previewWindowAvailabilityUnavailable: String { tr("preview.window.availability.unavailable") }

    static var previewHTMLBadge: String { tr("preview.html.badge") }
    static var previewHTMLSubtitle: String { tr("preview.html.subtitle") }
    static var previewHTMLSectionOverview: String { tr("preview.html.section.overview") }
    static var previewHTMLSectionEntitlements: String { tr("preview.html.section.entitlements") }
    static var previewHTMLSectionInfoPlist: String { tr("preview.html.section.info_plist") }
    static var previewHTMLSectionCertificates: String { tr("preview.html.section.certificates") }
    static var previewHTMLEmptyEntitlements: String { tr("preview.html.empty.entitlements") }
    static var previewHTMLEmptyInfoPlist: String { tr("preview.html.empty.info_plist") }
    static var previewHTMLEmptyCertificates: String { tr("preview.html.empty.certificates") }

    static var updateStrategyManual: String { tr("settings.update.manual") }
    static var updateStrategyDaily: String { tr("settings.update.daily") }
    static var updateStrategyOnLaunch: String { tr("settings.update.on_launch") }

    static func languageName(_ language: AppLanguage) -> String {
        switch language {
        case .english:
            return tr("settings.language.english")
        case .simplifiedChinese:
            return tr("settings.language.simplified")
        case .traditionalChinese:
            return tr("settings.language.traditional")
        }
    }

    static func appearanceName(_ appearance: AppAppearance) -> String {
        switch appearance {
        case .system:
            return tr("settings.appearance.system")
        case .light:
            return tr("settings.appearance.light")
        case .dark:
            return tr("settings.appearance.dark")
        }
    }

    static func currentVersion(_ shortVersion: String, _ buildVersion: String) -> String {
        tr("preferences.version", shortVersion, buildVersion)
    }

    static func localizedProfileType(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.isEmpty else { return "-" }

        switch rawValue {
        case "Development":
            return displayProfileTypeDevelopment
        case "Distribution (App Store)":
            return displayProfileTypeDistributionAppStore
        case "Distribution (Ad Hoc)":
            return displayProfileTypeDistributionAdHoc
        case "Enterprise":
            return displayProfileTypeEnterprise
        default:
            return rawValue
        }
    }

    static func localizedPlatform(_ rawValue: String?) -> String {
        guard let rawValue, !rawValue.isEmpty else { return "-" }

        switch rawValue {
        case "iOS":
            return displayPlatformIOS
        case "Mac":
            return displayPlatformMac
        default:
            return rawValue
        }
    }

    static func localizedFileType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "ipa":
            return "IPA"
        case "xcarchive":
            return "XCArchive"
        case "app":
            return "APP"
        case "appex":
            return "APPEX"
        case "mobileprovision":
            return displayFileTypeIOSProfile
        case "provisionprofile":
            return displayFileTypeMacProfile
        default:
            return displayFileTypeFile
        }
    }
}
