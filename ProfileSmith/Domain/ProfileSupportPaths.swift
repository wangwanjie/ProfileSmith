import Foundation

struct ScanLocation: Hashable {
    enum Kind: String {
        case mobileDevice
        case xcodeUserData
        case custom
    }

    let kind: Kind
    let url: URL
    let displayName: String
}

struct ProfileSupportPaths {
    let scanLocations: [ScanLocation]
    let renameBackupDirectory: URL
    let applicationSupportDirectory: URL
    let databaseURL: URL
    let embeddedQuickLookPlugInsDirectory: URL
    let embeddedQuickLookPreviewExtensionURL: URL
    let embeddedQuickLookThumbnailExtensionURL: URL

    init(bundle: Bundle = .main, environment: [String: String]) throws {
        let homeDirectory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)

        if let configuredDirectories = environment["PROFILESMITH_SCAN_DIRECTORIES"]?.splitPaths(), !configuredDirectories.isEmpty {
            scanLocations = configuredDirectories.enumerated().map { offset, rawPath in
                let url = URL(fileURLWithPath: rawPath, isDirectory: true)
                let name = url.lastPathComponent.isEmpty ? "目录 \(offset + 1)" : url.lastPathComponent
                return ScanLocation(kind: .custom, url: url, displayName: name)
            }
        } else {
            scanLocations = [
                ScanLocation(
                    kind: .mobileDevice,
                    url: homeDirectory
                        .appendingPathComponent("Library", isDirectory: true)
                        .appendingPathComponent("MobileDevice", isDirectory: true)
                        .appendingPathComponent("Provisioning Profiles", isDirectory: true),
                    displayName: "MobileDevice"
                ),
                ScanLocation(
                    kind: .xcodeUserData,
                    url: homeDirectory
                        .appendingPathComponent("Library", isDirectory: true)
                        .appendingPathComponent("Developer", isDirectory: true)
                        .appendingPathComponent("Xcode", isDirectory: true)
                        .appendingPathComponent("UserData", isDirectory: true)
                        .appendingPathComponent("Provisioning Profiles", isDirectory: true),
                    displayName: "Xcode UserData"
                ),
            ]
        }

        renameBackupDirectory = homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("MobileDevice", isDirectory: true)
            .appendingPathComponent("Provisioning Profiles Rename Backup", isDirectory: true)

        let applicationSupportDirectory: URL
        if let override = environment["PROFILESMITH_SUPPORT_DIRECTORY"], !override.isEmpty {
            applicationSupportDirectory = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            applicationSupportDirectory = homeDirectory
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .appendingPathComponent("ProfileSmith", isDirectory: true)
        }
        self.applicationSupportDirectory = applicationSupportDirectory
        databaseURL = applicationSupportDirectory.appendingPathComponent("ProfileSmith.sqlite", isDirectory: false)

        embeddedQuickLookPlugInsDirectory = bundle.builtInPlugInsURL
            ?? bundle.bundleURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("PlugIns", isDirectory: true)
        embeddedQuickLookPreviewExtensionURL = embeddedQuickLookPlugInsDirectory
            .appendingPathComponent("ProfileSmithQuickLookPreview.appex", isDirectory: true)
        embeddedQuickLookThumbnailExtensionURL = embeddedQuickLookPlugInsDirectory
            .appendingPathComponent("ProfileSmithQuickLookThumbnail.appex", isDirectory: true)

        try ensureDirectoriesExist()
    }

    var primaryInstallLocation: ScanLocation {
        scanLocations.first(where: { $0.kind == .mobileDevice }) ?? scanLocations[0]
    }

    private func ensureDirectoriesExist() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: renameBackupDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
    }
}

private extension String {
    func splitPaths() -> [String] {
        split(whereSeparator: { character in
            character == ":" || character == "\n"
        })
        .map(String.init)
        .filter { !$0.isEmpty }
    }
}
