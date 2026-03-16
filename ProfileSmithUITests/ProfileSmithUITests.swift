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
        let searchField = app.searchFields["main.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        app.activate()

        XCTAssertTrue(waitUntil(timeout: 10) {
            app.staticTexts["Alpha Dev"].exists && app.staticTexts["Beta Mac Store"].exists
        })
    }

    @MainActor
    func testSearchFiltersProfiles() throws {
        let app = launchApp()
        let searchField = app.searchFields["main.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        app.activate()
        XCTAssertTrue(waitUntil(timeout: 10) {
            app.staticTexts["Alpha Dev"].exists && app.staticTexts["Beta Mac Store"].exists
        })

        searchField.click()
        searchField.typeText("beta")

        XCTAssertTrue(waitUntil(timeout: 5) {
            app.staticTexts["Beta Mac Store"].exists && !app.staticTexts["Alpha Dev"].exists
        })
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
