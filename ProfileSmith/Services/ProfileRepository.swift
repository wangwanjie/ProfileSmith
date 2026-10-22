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
    /// 最近一次扫描中解析失败的文件路径，供界面提示用户。
    @Published private(set) var lastScanFailedPaths: [String] = []

    private let database: ProfileDatabase
    private let scanner: ProfileScanner
    private let parser: MobileProvisionParser
    private let archiveInspector: ArchiveInspector
    private let workQueue = DispatchQueue(label: "cn.vanjay.ProfileSmith.repository", qos: .userInitiated)

    private var query = ProfileQuery()
    private var pendingRefreshRequested = false
    private var pendingRefreshForceReindex = false
    private var directoryMonitor: ProfileDirectoryMonitor?

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

    /// 监听描述文件目录，Xcode 下载或删除描述文件后自动增量刷新，无需手动点击“刷新”。
    func startMonitoring(directories: [URL]) {
        guard directoryMonitor == nil else { return }
        let monitor = ProfileDirectoryMonitor(directories: directories) { [weak self] in
            self?.refresh(forceReindex: false)
        }
        monitor.start()
        directoryMonitor = monitor
    }

    func invalidate() {
        directoryMonitor?.stop()
        directoryMonitor = nil
        workQueue.sync {}
    }

    /// 当前所有已过期的描述文件（忽略界面上的搜索与筛选条件），用于“清理过期描述文件”。
    func fetchExpiredProfiles() throws -> [ProfileRecord] {
        try database.fetchProfiles(query: ProfileQuery(searchText: "", filter: .expired, sort: .nameAscending))
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
        if isRefreshing {
            pendingRefreshRequested = true
            pendingRefreshForceReindex = pendingRefreshForceReindex || forceReindex
            return
        }
        isRefreshing = true
        // 在主线程捕获查询条件再交给后台队列，避免后台读取 query 时与主线程修改产生数据竞争。
        let query = self.query

        workQueue.async { [weak self] in
            guard let self else { return }

            do {
                let scanResult = try self.scanner.scan(forceReindex: forceReindex)
                let profiles = try self.database.fetchProfiles(query: query)
                let metrics = try self.database.fetchMetrics()
                let date = Date()
                DispatchQueue.main.async {
                    self.lastScanFailedPaths = scanResult.failedPaths
                    self.snapshot = RepositorySnapshot(
                        profiles: profiles,
                        metrics: metrics,
                        query: query,
                        lastRefreshDate: date
                    )
                    self.isRefreshing = false
                    self.flushPendingRefreshIfNeeded()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isRefreshing = false
                    NSApp.presentError(error)
                    self.flushPendingRefreshIfNeeded()
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
        let query = self.query
        workQueue.async { [weak self] in
            guard let self else { return }

            do {
                let profiles = try self.database.fetchProfiles(query: query)
                let metrics = try self.database.fetchMetrics()
                DispatchQueue.main.async {
                    self.snapshot = RepositorySnapshot(
                        profiles: profiles,
                        metrics: metrics,
                        query: query,
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

    @MainActor
    private func flushPendingRefreshIfNeeded() {
        guard pendingRefreshRequested else { return }
        let forceReindex = pendingRefreshForceReindex
        pendingRefreshRequested = false
        pendingRefreshForceReindex = false
        refresh(forceReindex: forceReindex)
    }
}

#if DEBUG
extension ProfileRepository {
    @MainActor
    func debugSetRefreshState(_ isRefreshing: Bool, snapshot: RepositorySnapshot? = nil) {
        if let snapshot {
            self.snapshot = snapshot
        }
        self.isRefreshing = isRefreshing
    }
}
#endif
