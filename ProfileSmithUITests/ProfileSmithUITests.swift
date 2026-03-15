//
//  ProfileSmithUITests.swift
//  ProfileSmithUITests
//
//  Created by VanJay on 2026/3/16.
//

import XCTest

final class ProfileSmithUITests: XCTestCase {
    private var fixtureContext: UITestFixtureContext!

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixtureContext = try UITestFixtureContext()
    }

    override func tearDownWithError() throws {
        fixtureContext.cleanup()
        fixtureContext = nil
    }

    @MainActor
    func testLaunchLoadsFixtureProfilesAndUpdatesDetails() throws {
        let app = launchApp()
        let table = profilesTable(in: app)

        XCTAssertTrue(waitUntil(timeout: 10) { table.exists && self.rowCount(in: table) >= 2 })
        XCTAssertEqual(rowCount(in: table), 2)

        rowElement(in: table, at: 0).click()

        let titleLabel = app.staticTexts["main.titleLabel"]
        XCTAssertTrue(waitUntil(timeout: 5) { titleLabel.exists && titleLabel.label == "Alpha Dev" })
        XCTAssertEqual(titleLabel.label, "Alpha Dev")

        let summaryText = app.textViews["main.summaryTextView"]
        XCTAssertTrue(waitUntil(timeout: 5) { summaryText.exists && summaryText.value as? String != nil })
    }

    @MainActor
    func testSearchFiltersProfiles() throws {
        let app = launchApp()
        let table = profilesTable(in: app)
        XCTAssertTrue(waitUntil(timeout: 10) { table.exists && self.rowCount(in: table) >= 2 })

        let searchField = app.searchFields["main.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()
        searchField.typeText("beta")

        XCTAssertTrue(waitUntil(timeout: 5) { self.rowCount(in: table) == 1 })
        XCTAssertEqual(rowCount(in: table), 1)
        XCTAssertTrue(app.staticTexts["Beta Mac Store"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["PROFILESMITH_SCAN_DIRECTORIES"] = fixtureContext.scanDirectory.path
        app.launchEnvironment["PROFILESMITH_SUPPORT_DIRECTORY"] = fixtureContext.supportDirectory.path
        app.launchEnvironment["PROFILESMITH_UI_TEST"] = "1"
        app.launch()
        return app
    }

    private func profilesTable(in app: XCUIApplication) -> XCUIElement {
        let identified = app.tables["main.profilesTable"]
        return identified.exists ? identified : app.tables.firstMatch
    }

    private func rowCount(in table: XCUIElement) -> Int {
        table.descendants(matching: .tableRow).count
    }

    private func rowElement(in table: XCUIElement, at index: Int) -> XCUIElement {
        table.descendants(matching: .tableRow).element(boundBy: index)
    }

    private func waitUntil(timeout: TimeInterval, condition: @escaping () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
