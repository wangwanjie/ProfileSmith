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
        // 新系统或未安装过 Xcode 的机器上安装目录可能不存在，导入前先确保目录存在。
        try fileManager.createDirectory(at: installLocation.url, withIntermediateDirectories: true)

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
        // 导出目标就是源文件本身时直接返回，否则下面的“先删后拷”会把源文件删掉。
        if sourceURL.standardizedFileURL.resolvingSymlinksInPath() == destinationURL.standardizedFileURL.resolvingSymlinksInPath() {
            return
        }
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
        try fileManager.createDirectory(at: paths.renameBackupDirectory, withIntermediateDirectories: true)
        // 同一秒内多次美化同名文件时备份文件名会冲突，这里同样取一个不存在的文件名。
        let backupURL = uniqueFileURL(
            for: paths.renameBackupDirectory
                .appendingPathComponent("\(desiredBaseName)-\(timestamp)", isDirectory: false)
                .appendingPathExtension(record.fileExtension)
        )
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

    /// 导出证书：`.pem` 写 Base64 文本格式，其余（`.cer`/`.der`）写原始 DER 二进制，与系统钥匙串的约定保持一致。
    func exportCertificate(data: Data, to destinationURL: URL) throws {
        if destinationURL.pathExtension.lowercased() == "pem" {
            try Self.pemString(for: data).write(to: destinationURL, atomically: true, encoding: .utf8)
        } else {
            try data.write(to: destinationURL, options: .atomic)
        }
    }

    nonisolated static func pemString(for certificateData: Data) -> String {
        let base64 = certificateData.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----\n"
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
