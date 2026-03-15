import AppKit
import Combine
import Foundation

struct RepositorySnapshot: Equatable {
    var profiles: [ProfileRecord]
    var metrics: ProfileMetrics
    var query: ProfileQuery
    var lastRefreshDate: Date?

    static let empty = RepositorySnapshot(profiles: [], metrics: .empty, query: ProfileQuery(), lastRefreshDate: nil)
}

final class ProfileRepository {
    @Published private(set) var snapshot: RepositorySnapshot = .empty
    @Published private(set) var isRefreshing = false

    private let database: ProfileDatabase
    private let scanner: ProfileScanner
    private let parser: MobileProvisionParser
    private let archiveInspector: ArchiveInspector
    private let workQueue = DispatchQueue(label: "cn.vanjay.ProfileSmith.repository", qos: .userInitiated)

    private var query = ProfileQuery()

    init(database: ProfileDatabase, scanner: ProfileScanner, parser: MobileProvisionParser, archiveInspector: ArchiveInspector) {
        self.database = database
        self.scanner = scanner
        self.parser = parser
        self.archiveInspector = archiveInspector
    }

    func start() {
        reloadFromDatabase(lastRefreshDate: nil)
        refresh(forceReindex: false)
    }

    func invalidate() {
        workQueue.sync {}
    }

    func setSearchText(_ searchText: String) {
        guard query.searchText != searchText else { return }
        query.searchText = searchText
        reloadFromDatabase(lastRefreshDate: snapshot.lastRefreshDate)
    }

    func setFilter(_ filter: ProfileFilter) {
        guard query.filter != filter else { return }
        query.filter = filter
        reloadFromDatabase(lastRefreshDate: snapshot.lastRefreshDate)
    }

    func setSort(_ sort: ProfileSort) {
        guard query.sort != sort else { return }
        query.sort = sort
        reloadFromDatabase(lastRefreshDate: snapshot.lastRefreshDate)
    }

    func refresh(forceReindex: Bool) {
        guard !isRefreshing else { return }
        isRefreshing = true

        workQueue.async { [weak self] in
            guard let self else { return }

            do {
                _ = try self.scanner.scan(forceReindex: forceReindex)
                let profiles = try self.database.fetchProfiles(query: self.query)
                let metrics = try self.database.fetchMetrics()
                let date = Date()
                DispatchQueue.main.async {
                    self.snapshot = RepositorySnapshot(
                        profiles: profiles,
                        metrics: metrics,
                        query: self.query,
                        lastRefreshDate: date
                    )
                    self.isRefreshing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isRefreshing = false
                    NSApp.presentError(error)
                }
            }
        }
    }

    func loadProfileDetails(for record: ProfileRecord) throws -> ParsedProfile {
        let sourceLocation = ScanLocation(
            kind: ScanLocation.Kind(rawValue: record.sourceKind) ?? .custom,
            url: URL(fileURLWithPath: (record.path as NSString).deletingLastPathComponent, isDirectory: true),
            displayName: record.sourceName
        )
        return try parser.parseProfile(at: URL(fileURLWithPath: record.path), sourceLocation: sourceLocation)
    }

    func inspectArchive(at url: URL) throws -> PreviewInspection {
        try archiveInspector.inspect(url: url)
    }

    private func reloadFromDatabase(lastRefreshDate: Date?) {
        workQueue.async { [weak self] in
            guard let self else { return }

            do {
                let profiles = try self.database.fetchProfiles(query: self.query)
                let metrics = try self.database.fetchMetrics()
                DispatchQueue.main.async {
                    self.snapshot = RepositorySnapshot(
                        profiles: profiles,
                        metrics: metrics,
                        query: self.query,
                        lastRefreshDate: lastRefreshDate
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    NSApp.presentError(error)
                }
            }
        }
    }
}
