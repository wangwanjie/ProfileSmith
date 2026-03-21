import AppKit
import Foundation
import Testing
@testable import ProfileSmith

@Suite(.serialized)
struct PreferencesWindowControllerTests {
    @MainActor
    @Test
    func preferencesWindowExposesLanguageAndAppearanceControls() {
        let originalLanguage = AppLocalization.shared.language
        defer {
            AppLocalization.shared.setLanguage(originalLanguage)
        }

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

    @MainActor
    @Test
    func updatePaneButtonsRefreshWhenLanguageChanges() throws {
        let originalLanguage = AppLocalization.shared.language
        defer {
            AppLocalization.shared.setLanguage(originalLanguage)
        }

        let suiteName = "ProfileSmithTests.PreferencesWindow.Localization.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults)
        settings.appLanguage = .simplifiedChinese

        let controller = PreferencesWindowController(
            updateManager: UpdateManager(settings: settings),
            settings: settings
        )
        let window = try #require(controller.window)
        window.contentViewController?.loadViewIfNeeded()

        #expect(controller.debugCheckForUpdatesButtonTitle == L10n.preferencesCheckForUpdates)
        #expect(controller.debugOpenGitHubButtonTitle == L10n.preferencesOpenGitHub)

        settings.appLanguage = .english

        try waitUntil(
            description: "preferences update buttons refreshed after language switch",
            debugState: {
                "\(controller.debugCheckForUpdatesButtonTitle) | \(controller.debugOpenGitHubButtonTitle)"
            }
        ) {
            controller.debugCheckForUpdatesButtonTitle == L10n.preferencesCheckForUpdates
                && controller.debugOpenGitHubButtonTitle == L10n.preferencesOpenGitHub
        }
    }

    @MainActor
    @Test
    func preferencesCardReappliesResolvedBackgroundColorWhenAppearanceChanges() throws {
        let suiteName = "ProfileSmithTests.PreferencesWindow.Appearance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults)
        let controller = PreferencesWindowController(
            updateManager: UpdateManager(settings: settings),
            settings: settings
        )
        let window = try #require(controller.window)
        window.contentViewController?.loadViewIfNeeded()
        window.makeKeyAndOrderFront(nil)

        window.appearance = NSAppearance(named: .darkAqua)
        try waitUntil(
            description: "preferences card background updated for dark appearance",
            debugState: { "card=\(String(describing: controller.debugCardBackgroundColor))" }
        ) {
            colorsMatch(controller.debugCardBackgroundColor, expected: NSColor.controlBackgroundColor, appearance: controller.debugEffectiveAppearance)
        }

        window.appearance = NSAppearance(named: .aqua)
        try waitUntil(
            description: "preferences card background updated for light appearance",
            debugState: { "card=\(String(describing: controller.debugCardBackgroundColor))" }
        ) {
            colorsMatch(controller.debugCardBackgroundColor, expected: NSColor.controlBackgroundColor, appearance: controller.debugEffectiveAppearance)
        }
    }
}

private func colorsMatch(_ actual: NSColor?, expected: NSColor, appearance: NSAppearance) -> Bool {
    guard let actual = actual?.usingColorSpace(.deviceRGB) else { return false }
    let previousAppearance = NSAppearance.current
    NSAppearance.current = appearance
    let resolved = expected.usingColorSpace(.deviceRGB)
    NSAppearance.current = previousAppearance
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
        throw NSError(
            domain: "ProfileSmithTests.Timeout",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Condition '\(description)' was not satisfied within \(timeout) seconds. \(debugState())",
            ]
        )
    }
}
