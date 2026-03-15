import Foundation

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
        try? FileManager.default.removeItem(at: rootURL)
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
