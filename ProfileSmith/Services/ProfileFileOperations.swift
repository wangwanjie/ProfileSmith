import Cocoa

struct ImportResult {
    var installedURLs: [URL]
    var skippedURLs: [URL]
}

final class ProfileFileOperations {
    private let paths: ProfileSupportPaths
    private let parser: MobileProvisionParser
    private let fileManager = FileManager.default

    init(paths: ProfileSupportPaths, parser: MobileProvisionParser) {
        self.paths = paths
        self.parser = parser
    }

    func importProfiles(from urls: [URL]) throws -> ImportResult {
        var installedURLs: [URL] = []
        var skippedURLs: [URL] = []
        let installLocation = paths.primaryInstallLocation

        for url in urls where ProfileScanner.isSupportedProfileFile(url: url) {
            let parsed = try parser.parseProfile(at: url, sourceLocation: installLocation)
            let destinationBaseName = (parsed.record.uuid?.isEmpty == false ? parsed.record.uuid : url.deletingPathExtension().lastPathComponent) ?? url.deletingPathExtension().lastPathComponent
            let preferredDestinationURL = installLocation.url
                .appendingPathComponent(destinationBaseName, isDirectory: false)
                .appendingPathExtension(url.pathExtension.lowercased())
            let destinationURL = try safeDestinationURL(preferredURL: preferredDestinationURL, incomingURL: url)

            if fileManager.fileExists(atPath: destinationURL.path),
               url.standardizedFileURL != destinationURL.standardizedFileURL {
                let sourceData = try Data(contentsOf: url, options: [.mappedIfSafe])
                let destinationData = try Data(contentsOf: destinationURL, options: [.mappedIfSafe])
                if sourceData == destinationData {
                    skippedURLs.append(destinationURL)
                    continue
                }
            }

            if url.standardizedFileURL == destinationURL.standardizedFileURL {
                skippedURLs.append(destinationURL)
                continue
            }

            try fileManager.copyItem(at: url, to: destinationURL)
            installedURLs.append(destinationURL)
        }

        return ImportResult(installedURLs: installedURLs, skippedURLs: skippedURLs)
    }

    func deleteProfiles(at urls: [URL], permanently: Bool) throws {
        for url in urls {
            if permanently {
                try fileManager.removeItem(at: url)
            } else {
                try fileManager.trashItem(at: url, resultingItemURL: nil)
            }
        }
    }

    func exportProfile(from sourceURL: URL, to destinationURL: URL) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    func beautifyFilename(for record: ProfileRecord) throws -> URL {
        let currentURL = URL(fileURLWithPath: record.path)
        let desiredBaseName = sanitizeFileName(record.displayName)

        guard !desiredBaseName.isEmpty else {
            return currentURL
        }

        if currentURL.deletingPathExtension().lastPathComponent == desiredBaseName {
            return currentURL
        }

        let timestamp = Formatters.backupTimestampString(from: Date())
        let backupURL = paths.renameBackupDirectory
            .appendingPathComponent("\(desiredBaseName)-\(timestamp)", isDirectory: false)
            .appendingPathExtension(record.fileExtension)
        let preferredDestinationURL = currentURL.deletingLastPathComponent()
            .appendingPathComponent(desiredBaseName, isDirectory: false)
            .appendingPathExtension(record.fileExtension)
        let destinationURL = uniqueFileURL(for: preferredDestinationURL)

        if currentURL.standardizedFileURL == destinationURL.standardizedFileURL {
            return currentURL
        }

        try fileManager.copyItem(at: currentURL, to: backupURL)
        try fileManager.moveItem(at: currentURL, to: destinationURL)
        return destinationURL
    }

    func exportCertificate(data: Data, summary: CertificateSummary, to directoryURL: URL) throws -> URL {
        let fileName = sanitizeFileName(summary.summary).isEmpty ? "Certificate" : sanitizeFileName(summary.summary)
        let outputURL = directoryURL.appendingPathComponent(fileName).appendingPathExtension("cer")
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private func safeDestinationURL(preferredURL: URL, incomingURL: URL) throws -> URL {
        guard fileManager.fileExists(atPath: preferredURL.path) else {
            return preferredURL
        }

        if incomingURL.standardizedFileURL == preferredURL.standardizedFileURL {
            return preferredURL
        }

        let sourceData = try Data(contentsOf: incomingURL, options: [.mappedIfSafe])
        let destinationData = try Data(contentsOf: preferredURL, options: [.mappedIfSafe])
        if sourceData == destinationData {
            return preferredURL
        }

        return uniqueFileURL(for: preferredURL)
    }

    private func uniqueFileURL(for url: URL) -> URL {
        guard fileManager.fileExists(atPath: url.path) else {
            return url
        }

        let directory = url.deletingLastPathComponent()
        let fileExtension = url.pathExtension
        let baseName = url.deletingPathExtension().lastPathComponent

        for index in 2...999 {
            let candidate = directory
                .appendingPathComponent("\(baseName)-\(index)", isDirectory: false)
                .appendingPathExtension(fileExtension)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return directory
            .appendingPathComponent("\(baseName)-\(UUID().uuidString.prefix(8))", isDirectory: false)
            .appendingPathExtension(fileExtension)
    }

    private func sanitizeFileName(_ input: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = input
            .components(separatedBy: invalidCharacters)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
    }
}
