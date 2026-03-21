import Foundation
import Testing
@testable import ProfileSmith

struct LocalizationTests {
    @Test
    func appLanguageResolvesSupportedIdentifiers() {
        #expect(AppLanguage.resolve("en") == .english)
        #expect(AppLanguage.resolve("en-US") == .english)
        #expect(AppLanguage.resolve("zh-Hans") == .simplifiedChinese)
        #expect(AppLanguage.resolve("zh-CN") == .simplifiedChinese)
        #expect(AppLanguage.resolve("zh-Hant") == .traditionalChinese)
        #expect(AppLanguage.resolve("zh-TW") == .traditionalChinese)
    }

    @Test
    func appLanguageFallsBackFromPreferredLanguages() {
        #expect(AppLanguage.preferred(from: ["fr-FR", "zh-HK"]) == .traditionalChinese)
        #expect(AppLanguage.preferred(from: ["ja-JP", "zh-CN"]) == .simplifiedChinese)
        #expect(AppLanguage.preferred(from: ["fr-FR", "de-DE"]) == .english)
    }
}
