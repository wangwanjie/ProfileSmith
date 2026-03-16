import Foundation

enum QuickLookPluginError: LocalizedError {
    case embeddedExtensionsMissing
    case registrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .embeddedExtensionsMissing:
            return "应用内未找到 Finder Quick Look 扩展。"
        case .registrationFailed(let output):
            return output.isEmpty ? "Finder Quick Look 刷新失败。" : output
        }
    }
}

final class QuickLookPluginManager {
    private enum Constants {
        static let previewBundleIdentifier = "cn.vanjay.ProfileSmith.QuickLookPreview"
        static let thumbnailBundleIdentifier = "cn.vanjay.ProfileSmith.QuickLookThumbnail"
    }

    private let paths: ProfileSupportPaths
    private let fileManager = FileManager.default

    init(paths: ProfileSupportPaths) {
        self.paths = paths
    }

    var isAvailable: Bool {
        embeddedExtensionURLs.allSatisfy { fileManager.fileExists(atPath: $0.path) }
    }

    var isRegistered: Bool {
        guard isAvailable else { return false }
        let registered = registeredBundleIdentifiers()
        return registered.contains(Constants.previewBundleIdentifier) && registered.contains(Constants.thumbnailBundleIdentifier)
    }

    func refreshRegistration() throws {
        guard isAvailable else {
            throw QuickLookPluginError.embeddedExtensionsMissing
        }

        for extensionURL in embeddedExtensionURLs {
            try run(executable: "/usr/bin/pluginkit", arguments: ["-a", extensionURL.path])
        }
        try run(executable: "/usr/bin/qlmanage", arguments: ["-r"])
        try run(executable: "/usr/bin/qlmanage", arguments: ["-r", "cache"])
    }

    var buttonTitle: String {
        guard isAvailable else { return "Finder Quick Look 不可用" }
        return isRegistered ? "刷新 Finder Quick Look" : "启用 Finder Quick Look"
    }

    var stateDescription: String {
        guard isAvailable else { return "未嵌入 Finder Quick Look 扩展" }
        return isRegistered ? "Finder Quick Look 已就绪" : "Finder Quick Look 待刷新"
    }

    var embeddedExtensionURLs: [URL] {
        [
            paths.embeddedQuickLookPreviewExtensionURL,
            paths.embeddedQuickLookThumbnailExtensionURL,
        ]
    }

    private func registeredBundleIdentifiers() -> Set<String> {
        guard let output = try? run(executable: "/usr/bin/pluginkit", arguments: ["-m", "-A", "-D"]) else {
            return []
        }

        var identifiers = Set<String>()
        for line in output.split(separator: "\n") {
            let text = String(line)
            if text.contains(Constants.previewBundleIdentifier) {
                identifiers.insert(Constants.previewBundleIdentifier)
            }
            if text.contains(Constants.thumbnailBundleIdentifier) {
                identifiers.insert(Constants.thumbnailBundleIdentifier)
            }
        }
        return identifiers
    }

    @discardableResult
    private func run(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw QuickLookPluginError.registrationFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }
}
