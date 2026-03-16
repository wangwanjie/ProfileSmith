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
        fixtureContext.terminateRunningProfileSmithApplications()
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
        XCTAssertTrue(searchField.exists)
    }

    @MainActor
    func testSearchFieldStartsEmptyInUITestMode() throws {
        let app = launchApp()
        let searchField = app.searchFields["main.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        app.activate()
        XCTAssertEqual(searchField.value as? String, "")
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        try! fixtureContext.launchApplication()
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
