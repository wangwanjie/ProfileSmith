import AppKit
import Foundation
import Testing
@testable import ProfileSmith

@Suite(.serialized)
struct AppSettingsTests {
    @MainActor
    @Test
    func updateCheckStrategyPersistsToUserDefaults() {
        let suiteName = "ProfileSmithTests.AppSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults)
        #expect(settings.updateCheckStrategy == .daily)

        settings.updateCheckStrategy = .onLaunch

        let reloadedSettings = AppSettings(defaults: defaults)
        #expect(reloadedSettings.updateCheckStrategy == .onLaunch)

        settings.resetToDefaults()
        #expect(settings.updateCheckStrategy == .daily)
    }

    @MainActor
    @Test
    func languageAndAppearancePersistToUserDefaults() {
        let suiteName = "ProfileSmithTests.AppSettings.RuntimePreferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults)
        #expect(settings.appLanguage == .simplifiedChinese)
        #expect(settings.appAppearance == .system)

        settings.appLanguage = .traditionalChinese
        settings.appAppearance = .dark

        let reloadedSettings = AppSettings(defaults: defaults)
        #expect(reloadedSettings.appLanguage == .traditionalChinese)
        #expect(reloadedSettings.appAppearance == .dark)

        settings.resetToDefaults()
        #expect(settings.appLanguage == .simplifiedChinese)
        #expect(settings.appAppearance == .system)
    }

    @MainActor
    @Test
    func initializingSettingsAppliesPersistedRuntimePreferences() {
        let suiteName = "ProfileSmithTests.AppSettings.ApplyRuntimePreferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            AppLocalization.shared.setLanguage(.simplifiedChinese)
            AppearanceManager.shared.apply(.system)
        }

        defaults.set(AppLanguage.english.rawValue, forKey: "ProfileSmithAppLanguage")
        defaults.set(AppAppearance.dark.rawValue, forKey: "ProfileSmithAppAppearance")

        AppLocalization.shared.setLanguage(.simplifiedChinese)
        AppearanceManager.shared.apply(.system)

        _ = AppSettings(defaults: defaults)

        #expect(AppLocalization.shared.language == .english)
        #expect(NSApp.appearance?.name == .darkAqua)
    }
}
