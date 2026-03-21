import Foundation
import Testing
@testable import ProfileSmith

@Suite(.serialized)
struct StatusItemControllerTests {
    @MainActor
    @Test
    func statusMenuContentRefreshesWhenLanguageChanges() {
        let originalLanguage = AppLocalization.shared.language
        defer {
            AppLocalization.shared.setLanguage(originalLanguage)
        }

        let snapshot = RepositorySnapshot(
            profiles: [],
            metrics: ProfileMetrics(totalCount: 2, expiredCount: 1, expiringSoonCount: 1),
            query: ProfileQuery(),
            lastRefreshDate: nil
        )

        AppLocalization.shared.setLanguage(.simplifiedChinese)
        let chineseContent = StatusItemMenuContent(
            snapshot: snapshot,
            quickLookButtonTitle: L10n.quickLookRefresh,
            quickLookAvailable: true
        )

        #expect(chineseContent.buttonTitle == "PS !1")
        #expect(chineseContent.visibleTitles.contains("已索引 2 个描述文件"))
        #expect(chineseContent.visibleTitles.contains("打开 ProfileSmith"))
        #expect(chineseContent.visibleTitles.contains("检查更新…"))

        AppLocalization.shared.setLanguage(.english)
        let englishContent = StatusItemMenuContent(
            snapshot: snapshot,
            quickLookButtonTitle: L10n.quickLookRefresh,
            quickLookAvailable: true
        )

        #expect(englishContent.buttonTitle == "PS !1")
        #expect(englishContent.visibleTitles.contains("Indexed 2 profiles"))
        #expect(englishContent.visibleTitles.contains("Open ProfileSmith"))
        #expect(englishContent.visibleTitles.contains("Check for Updates…"))
    }
}
