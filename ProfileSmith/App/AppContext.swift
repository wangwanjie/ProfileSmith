import Foundation

final class AppContext {
    let supportPaths: ProfileSupportPaths
    let parser: MobileProvisionParser
    let archiveInspector: ArchiveInspector
    let database: ProfileDatabase
    let scanner: ProfileScanner
    let fileOperations: ProfileFileOperations
    let quickLookPluginManager: QuickLookPluginManager
    let repository: ProfileRepository
    let updateManager: UpdateManager

    init(bundle: Bundle = .main, environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        supportPaths = try ProfileSupportPaths(bundle: bundle, environment: environment)
        parser = MobileProvisionParser()
        archiveInspector = ArchiveInspector(parser: parser)
        database = try ProfileDatabase(databaseURL: supportPaths.databaseURL)
        scanner = ProfileScanner(paths: supportPaths, parser: parser, database: database)
        fileOperations = ProfileFileOperations(paths: supportPaths, parser: parser)
        quickLookPluginManager = QuickLookPluginManager(paths: supportPaths)
        repository = ProfileRepository(database: database, scanner: scanner, parser: parser, archiveInspector: archiveInspector)
        updateManager = UpdateManager()
    }

    func invalidate() {
        repository.invalidate()
        try? database.close()
    }
}
