import Foundation

enum QuickLookPluginError: LocalizedError {
    case embeddedExtensionsMissing
    case registrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .embeddedExtensionsMissing:
            return L10n.quickLookMissingExtensions
        case .registrationFailed(let output):
            return output.isEmpty ? L10n.quickLookRefreshFailed : output
        }
    }
}

final class QuickLookPluginManager {
    typealias CommandRunner = (String, [String]) throws -> String
    typealias RegisteredBundleIdentifiersProvider = () -> Set<String>

    static let previewBundleIdentifier = "cn.vanjay.ProfileSmith.QuickLookPreview"
    static let thumbnailBundleIdentifier = "cn.vanjay.ProfileSmith.QuickLookThumbnail"

    private let paths: ProfileSupportPaths
    private let fileManager = FileManager.default
    private let commandRunner: CommandRunner
    private let registeredBundleIdentifiersProvider: RegisteredBundleIdentifiersProvider

    init(
        paths: ProfileSupportPaths,
        commandRunner: CommandRunner? = nil,
        registeredBundleIdentifiersProvider: RegisteredBundleIdentifiersProvider? = nil
    ) {
        let resolvedCommandRunner = commandRunner ?? Self.runCommand
        self.paths = paths
        self.commandRunner = resolvedCommandRunner
        self.registeredBundleIdentifiersProvider = registeredBundleIdentifiersProvider ?? {
            Self.registeredBundleIdentifiers(commandRunner: resolvedCommandRunner)
        }
    }

    var isAvailable: Bool {
        fileManager.fileExists(atPath: paths.embeddedQuickLookPreviewExtensionURL.path)
    }

    var isRegistered: Bool {
        guard isAvailable else { return false }
        let registered = registeredBundleIdentifiersProvider()
        return registered.contains(Self.previewBundleIdentifier)
    }

    func refreshRegistration() throws {
        guard isAvailable else {
            throw QuickLookPluginError.embeddedExtensionsMissing
        }

        _ = try commandRunner("/usr/bin/pluginkit", ["-a", paths.embeddedQuickLookPreviewExtensionURL.path])
        _ = try commandRunner("/usr/bin/pluginkit", ["-e", "use", "-i", Self.previewBundleIdentifier])
        _ = try? commandRunner("/usr/bin/pluginkit", ["-e", "ignore", "-i", Self.thumbnailBundleIdentifier])
        _ = try commandRunner("/usr/bin/qlmanage", ["-r"])
        _ = try commandRunner("/usr/bin/qlmanage", ["-r", "cache"])
    }

    var buttonTitle: String {
        guard isAvailable else { return L10n.quickLookUnavailable }
        return isRegistered ? L10n.quickLookRefresh : L10n.quickLookEnable
    }

    var stateDescription: String {
        guard isAvailable else { return L10n.quickLookMissingExtensions }
        return isRegistered ? L10n.quickLookReady : L10n.quickLookPending
    }

    private nonisolated static func registeredBundleIdentifiers(commandRunner: CommandRunner) -> Set<String> {
        guard let output = try? commandRunner("/usr/bin/pluginkit", ["-m", "-A", "-D"]) else {
            return []
        }

        var identifiers = Set<String>()
        for line in output.split(separator: "\n") {
            let text = String(line)
            if text.contains(Self.previewBundleIdentifier) {
                identifiers.insert(Self.previewBundleIdentifier)
            }
        }
        return identifiers
    }

    @discardableResult
    private nonisolated static func runCommand(executable: String, arguments: [String]) throws -> String {
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
