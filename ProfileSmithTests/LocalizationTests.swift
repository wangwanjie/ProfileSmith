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

    @Test
    func allLanguagesDefineTheSameLocalizationKeys() throws {
        // 任何一种语言漏翻都会让界面直接显示 key，这里保证三种语言的 key 集合完全一致。
        var keySets: [String: Set<String>] = [:]
        for language in AppLanguage.allCases {
            let url = try #require(Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language.rawValue))
            let dictionary = try #require(NSDictionary(contentsOf: url) as? [String: String])
            keySets[language.rawValue] = Set(dictionary.keys)
        }

        let englishKeys = try #require(keySets[AppLanguage.english.rawValue])
        #expect(!englishKeys.isEmpty)
        for (language, keys) in keySets {
            #expect(keys.subtracting(englishKeys).isEmpty, "\(language) 多出的 key: \(keys.subtracting(englishKeys).sorted())")
            #expect(englishKeys.subtracting(keys).isEmpty, "\(language) 缺失的 key: \(englishKeys.subtracting(keys).sorted())")
        }
    }

    @Test
    func formatPlaceholdersMatchAcrossLanguages() throws {
        // 占位符数量或类型不一致会导致 String(format:) 崩溃或输出错乱。
        func placeholders(in format: String) -> [String] {
            let regex = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?[@dDuUxXoOfeEgGcCsSpaAF]|%ld|%lu")
            let range = NSRange(format.startIndex..., in: format)
            return regex.matches(in: format, range: range).compactMap { Range($0.range, in: format).map { String(format[$0]) } }
        }

        var tables: [String: [String: String]] = [:]
        for language in AppLanguage.allCases {
            let url = try #require(Bundle.main.url(forResource: "Localizable", withExtension: "strings", subdirectory: nil, localization: language.rawValue))
            tables[language.rawValue] = try #require(NSDictionary(contentsOf: url) as? [String: String])
        }

        let english = try #require(tables[AppLanguage.english.rawValue])
        for (key, englishValue) in english {
            for language in AppLanguage.allCases where language != .english {
                guard let value = tables[language.rawValue]?[key] else { continue }
                #expect(placeholders(in: value) == placeholders(in: englishValue), "\(language.rawValue) 的 \(key) 占位符与英文不一致")
            }
        }
    }

    @Test
    func newProfileTypeIsLocalizedInEveryLanguage() {
        let localization = AppLocalization(bundle: .main, initialLanguage: .english)
        #expect(localization.string("display.profile_type.distribution_developer_id") == "Distribution (Developer ID)")
        localization.setLanguage(.simplifiedChinese)
        #expect(localization.string("display.profile_type.distribution_developer_id") == "分发（Developer ID）")
        localization.setLanguage(.traditionalChinese)
        #expect(localization.string("display.profile_type.distribution_developer_id") == "發佈（Developer ID）")
    }

    @Test
    func releaseVersionComparesNumericComponents() {
        #expect(ReleaseVersion("1.4.3") < ReleaseVersion("1.5.0"))
        #expect(ReleaseVersion("v1.10.0") > ReleaseVersion("1.9.9"))
        #expect(ReleaseVersion("1.5") == ReleaseVersion("v1.5.0"))
        #expect(!(ReleaseVersion("1.5.0") < ReleaseVersion("1.5")))
        #expect(ReleaseVersion("2") > ReleaseVersion("1.99.99"))
    }
}
