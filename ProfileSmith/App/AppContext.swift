import Foundation

final class AppContext {
    let supportPaths: ProfileSupportPaths
    let parser: MobileProvisionParser
    let database: ProfileDatabase
    let scanner: ProfileScanner
    let fileOperations: ProfileFileOperations
    let repository: ProfileRepository
    let updateManager: UpdateManager

    init(bundle: Bundle = .main, environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        supportPaths = try ProfileSupportPaths(bundle: bundle, environment: environment)
        parser = MobileProvisionParser()
        database = try ProfileDatabase(databaseURL: supportPaths.databaseURL)
        scanner = ProfileScanner(paths: supportPaths, parser: parser, database: database)
        fileOperations = ProfileFileOperations(paths: supportPaths, parser: parser)
        repository = ProfileRepository(database: database, scanner: scanner, parser: parser)
        updateManager = UpdateManager()
    }

    func invalidate() {
        repository.invalidate()
        try? database.close()
    }
}
