import Foundation

struct ScanResult {
    var changedCount: Int
    var removedCount: Int
}

final class ProfileScanner {
    private let paths: ProfileSupportPaths
    private let parser: MobileProvisionParser
    private let database: ProfileDatabase
    private let fileManager = FileManager.default

    init(paths: ProfileSupportPaths, parser: MobileProvisionParser, database: ProfileDatabase) {
        self.paths = paths
        self.parser = parser
        self.database = database
    }

    func scan(forceReindex: Bool) throws -> ScanResult {
        let existingStates = forceReindex ? [:] : try database.indexedFileStates()
        let fileURLsByPath = discoveredProfileFiles()

        var changedRecords: [ProfileRecord] = []
        var removedPaths = Set(existingStates.keys)

        for (path, payload) in fileURLsByPath {
            removedPaths.remove(path)

            let shouldReparse: Bool
            if let state = existingStates[path], !forceReindex {
                shouldReparse = state.fileSize != payload.fileSize || state.fileModificationTime != payload.modificationTime
            } else {
                shouldReparse = true
            }

            guard shouldReparse else { continue }
            let parsedProfile = try parser.parseProfile(at: payload.url, sourceLocation: payload.location)
            changedRecords.append(parsedProfile.record)
        }

        try database.save(records: changedRecords, removingPaths: Array(removedPaths))

        return ScanResult(changedCount: changedRecords.count, removedCount: removedPaths.count)
    }

    private func discoveredProfileFiles() -> [String: (url: URL, location: ScanLocation, fileSize: Int64, modificationTime: TimeInterval)] {
        var result: [String: (url: URL, location: ScanLocation, fileSize: Int64, modificationTime: TimeInterval)] = [:]

        for location in paths.scanLocations {
            guard let enumerator = fileManager.enumerator(
                at: location.url,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard Self.isSupportedProfileFile(url: fileURL) else { continue }
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
                guard values?.isRegularFile == true else { continue }
                result[fileURL.path] = (
                    url: fileURL,
                    location: location,
                    fileSize: Int64(values?.fileSize ?? 0),
                    modificationTime: values?.contentModificationDate?.timeIntervalSince1970 ?? 0
                )
            }
        }

        return result
    }

    nonisolated static func isSupportedProfileFile(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "mobileprovision" || ext == "provisionprofile"
    }
}
