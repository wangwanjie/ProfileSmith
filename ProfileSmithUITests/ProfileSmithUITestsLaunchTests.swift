//
//  ProfileSmithUITestsLaunchTests.swift
//  ProfileSmithUITests
//
//  Created by VanJay on 2026/3/16.
//

import XCTest

final class ProfileSmithUITestsLaunchTests: XCTestCase {
    private var fixtureContext: UITestFixtureContext!

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixtureContext = try UITestFixtureContext()
    }

    override func tearDownWithError() throws {
        fixtureContext.cleanup()
        fixtureContext = nil
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["PROFILESMITH_SCAN_DIRECTORIES"] = fixtureContext.scanDirectory.path
        app.launchEnvironment["PROFILESMITH_SUPPORT_DIRECTORY"] = fixtureContext.supportDirectory.path
        app.launchEnvironment["PROFILESMITH_UI_TEST"] = "1"
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
