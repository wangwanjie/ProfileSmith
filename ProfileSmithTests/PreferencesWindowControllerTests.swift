import AppKit
import Foundation
import Testing
@testable import ProfileSmith

@Suite(.serialized)
struct PreferencesWindowControllerTests {
    @MainActor
    @Test
    func preferencesWindowExposesLanguageAndAppearanceControls() {
        let suiteName = "ProfileSmithTests.PreferencesWindow.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults)
        settings.appLanguage = .english
        settings.appAppearance = .dark

        let controller = PreferencesWindowController(
            updateManager: UpdateManager(settings: settings),
            settings: settings
        )
        controller.window?.contentViewController?.loadViewIfNeeded()

        #expect(controller.debugLanguagePopup.itemTitles == AppLanguage.allCases.map(L10n.languageName))
        #expect(controller.debugAppearancePopup.itemTitles == AppAppearance.allCases.map(L10n.appearanceName))
        #expect(controller.debugLanguagePopup.indexOfSelectedItem == 0)
        #expect(controller.debugAppearancePopup.indexOfSelectedItem == 2)
    }
}
