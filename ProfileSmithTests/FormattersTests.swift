import Foundation
import Testing
@testable import ProfileSmith

struct FormattersTests {
    @Test
    func plistValuesRenderAsReadableSingleLineText() {
        #expect(Formatters.plistValueString(true) == "true")
        #expect(Formatters.plistValueString(NSNumber(value: false)) == "false")
        // 普通数字 1 不能被误判成布尔值 true。
        #expect(Formatters.plistValueString(NSNumber(value: 1)) == "1")
        #expect(Formatters.plistValueString("production") == "production")
        #expect(Formatters.plistValueString(["TEAM.*", "TEAM.com.example"]) == "[TEAM.*, TEAM.com.example]")
        #expect(Formatters.plistValueString(["b": 2, "a": true] as [String: Any]) == "{a: true, b: 2}")
        #expect(Formatters.plistValueString(Data([0x01, 0x02])) == "AQI=")
    }

    @Test
    func backupTimestampIsLocaleIndependent() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 7, minute: 8, second: 9))!
        #expect(Formatters.backupTimestampString(from: date) == "20260305-070809")
        #expect(Formatters.dayString(from: date) == "2026-03-05")
        #expect(Formatters.timestampString(from: date) == "2026-03-05 07:08")
    }
}

struct SplitViewAutosaveTests {
    @MainActor
    @Test
    func readsLeadingPaneWidthFromAutosaveRecord() {
        let suiteName = "ProfileSmithTests.SplitAutosave.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let key = "NSSplitView Subview Frames Test.Split"

        #expect(MainViewController.savedLeadingPaneWidth(autosaveName: "Test.Split", defaults: defaults) == nil)

        defaults.set(["0.000000, 0.000000, 812.500000, 760.000000, NO, NO", "813.500000, 0.000000, 600.000000, 760.000000, NO, NO"], forKey: key)
        #expect(MainViewController.savedLeadingPaneWidth(autosaveName: "Test.Split", defaults: defaults) == 812.5)

        // 折叠或零宽度的记录无效。
        defaults.set(["0.000000, 0.000000, 0.000000, 760.000000, NO, NO"], forKey: key)
        #expect(MainViewController.savedLeadingPaneWidth(autosaveName: "Test.Split", defaults: defaults) == nil)
        defaults.set(["0.000000, 0.000000, 400.000000, 760.000000, YES, NO"], forKey: key)
        #expect(MainViewController.savedLeadingPaneWidth(autosaveName: "Test.Split", defaults: defaults) == nil)

        #expect(MainViewController.savedLeadingPaneWidth(autosaveName: nil, defaults: defaults) == nil)
    }
}
