import Foundation

enum QuickLookPluginError: LocalizedError {
    case bundledArchiveMissing
    case installationFailed
    case removalFailed

    var errorDescription: String? {
        switch self {
        case .bundledArchiveMissing:
            return "应用内未找到可安装的 Quick Look 插件资源。"
        case .installationFailed:
            return "Quick Look 插件安装失败。"
        case .removalFailed:
            return "Quick Look 插件移除失败。"
        }
    }
}

final class QuickLookPluginManager {
    private let paths: ProfileSupportPaths
    private let fileManager = FileManager.default

    init(paths: ProfileSupportPaths) {
        self.paths = paths
    }

    var isInstalled: Bool {
        fileManager.fileExists(atPath: paths.quickLookInstalledBundleURL.path)
    }

    func installBundledPlugin() throws {
        guard let archiveURL = paths.bundledQuickLookArchiveURL else {
            throw QuickLookPluginError.bundledArchiveMissing
        }

        if isInstalled {
            try uninstallPlugin()
        }

        try run(executable: "/usr/bin/ditto", arguments: ["-x", "-k", archiveURL.path, paths.quickLookDirectory.path])
        try refreshQuickLookServer()
    }

    func uninstallPlugin() throws {
        guard isInstalled else { return }
        do {
            try fileManager.trashItem(at: paths.quickLookInstalledBundleURL, resultingItemURL: nil)
            try refreshQuickLookServer()
        } catch {
            throw QuickLookPluginError.removalFailed
        }
    }

    func refreshQuickLookServer() throws {
        try run(executable: "/usr/bin/qlmanage", arguments: ["-r"])
        try run(executable: "/usr/bin/qlmanage", arguments: ["-r", "cache"])
    }

    private func run(executable: String, arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw QuickLookPluginError.installationFailed
        }
    }
}
