import Foundation
import Testing
@testable import ProfileSmith

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
}
