import AppKit
import Darwin
import Foundation
import XCTest

final class UITestFixtureContext {
    let rootURL: URL
    let scanDirectory: URL
    let supportDirectory: URL

    init() throws {
        let temporaryRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        rootURL = temporaryRoot.appendingPathComponent("ProfileSmithUITests-\(UUID().uuidString)", isDirectory: true)
        scanDirectory = rootURL.appendingPathComponent("Profiles", isDirectory: true)
        supportDirectory = rootURL.appendingPathComponent("Support", isDirectory: true)

        try FileManager.default.createDirectory(at: scanDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)

        try writeProfile(
            to: scanDirectory,
            fileName: "alpha-dev",
            name: "Alpha Dev",
            uuid: "UI-ALPHA-AAAA-BBBB-CCCC",
            teamName: "Alpha Team",
            teamIdentifier: "ALPHA1234",
            bundleIdentifier: "com.example.alpha",
            isDevelopment: true,
            platform: "iOS",
            expirationDate: Date(timeIntervalSince1970: 1_900_000_000)
        )
        try writeProfile(
            to: scanDirectory,
            fileName: "beta-mac",
            name: "Beta Mac Store",
            uuid: "UI-BETA-AAAA-BBBB-CCCC",
            teamName: "Beta Team",
            teamIdentifier: "BETA1234",
            bundleIdentifier: "com.example.beta.mac",
            isDevelopment: false,
            platform: "Mac",
            expirationDate: Date(timeIntervalSince1970: 1_650_000_000)
        )
    }

    func cleanup() {
        terminateRunningProfileSmithApplications()
        try? FileManager.default.removeItem(at: rootURL)
    }

    func launchApplication() throws -> XCUIApplication {
        terminateRunningProfileSmithApplications()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [
            "-n",
            "-F",
            "-a",
            try profileSmithBundleURL().path,
            "--env",
            "PROFILESMITH_SCAN_DIRECTORIES=\(scanDirectory.path)",
            "--env",
            "PROFILESMITH_SUPPORT_DIRECTORY=\(supportDirectory.path)",
            "--env",
            "PROFILESMITH_UI_TEST=1",
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "ProfileSmithUITests",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "open failed with exit code \(process.terminationStatus)."]
            )
        }

        let app = XCUIApplication(bundleIdentifier: "cn.vanjay.ProfileSmith")
        guard waitUntil(timeout: 10, condition: {
            !NSRunningApplication.runningApplications(withBundleIdentifier: "cn.vanjay.ProfileSmith").isEmpty
        }) else {
            throw NSError(
                domain: "ProfileSmithUITests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "ProfileSmith did not reach a running state in time."]
            )
        }

        app.activate()
        guard app.wait(for: .runningForeground, timeout: 10) else {
            throw NSError(
                domain: "ProfileSmithUITests",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "ProfileSmith did not become the foreground application in time."]
            )
        }
        return app
    }

    func terminateRunningProfileSmithApplications() {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            let runningApplications = NSRunningApplication.runningApplications(withBundleIdentifier: "cn.vanjay.ProfileSmith")
            guard !runningApplications.isEmpty else { return }

            for application in runningApplications {
                if !application.terminate() {
                    _ = application.forceTerminate()
                }
                if !application.isTerminated {
                    kill(application.processIdentifier, SIGKILL)
                }
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
    }

    private func profileSmithBundleURL() throws -> URL {
        let appBundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("ProfileSmith.app", isDirectory: true)

        guard FileManager.default.fileExists(atPath: appBundleURL.path) else {
            throw NSError(
                domain: "ProfileSmithUITests",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to locate ProfileSmith app bundle at \(appBundleURL.path)"]
            )
        }

        return appBundleURL
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

    private func writeProfile(
        to directoryURL: URL,
        fileName: String,
        name: String,
        uuid: String,
        teamName: String,
        teamIdentifier: String,
        bundleIdentifier: String,
        isDevelopment: Bool,
        platform: String,
        expirationDate: Date
    ) throws {
        let extensionName = platform == "Mac" ? "provisionprofile" : "mobileprovision"
        let url = directoryURL.appendingPathComponent(fileName).appendingPathExtension(extensionName)
        let plist: [String: Any] = [
            "Name": name,
            "UUID": uuid,
            "TeamName": teamName,
            "TeamIdentifier": [teamIdentifier],
            "ApplicationIdentifierPrefix": [teamIdentifier],
            "AppIDName": name,
            "CreationDate": Date(timeIntervalSince1970: 1_700_000_000),
            "ExpirationDate": expirationDate,
            "Platform": [platform],
            "DeveloperCertificates": [],
            "Entitlements": [
                "application-identifier": "\(teamIdentifier).\(bundleIdentifier)",
                "get-task-allow": isDevelopment,
            ],
            "ProvisionedDevices": isDevelopment ? ["DEVICE-001", "DEVICE-002"] : [],
        ]

        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        var data = Data("FAKECMS\n".utf8)
        data.append(plistData)
        data.append(Data("\nFAKECMS-END".utf8))
        try data.write(to: url)
    }
}
