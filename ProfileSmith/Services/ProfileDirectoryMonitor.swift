import Foundation

/// 监听描述文件所在目录的变化（新增、删除、重命名），合并短时间内的多次事件后回调一次。
///
/// 目录不存在时（例如从未安装过描述文件），会退而监听最近的已存在上级目录，
/// 待目录被创建后自动切换为监听目标目录本身。
///
/// 所有内部状态只在私有串行队列上读写；回调通过 `RunLoop.main.perform` 投递到主线程，
/// 这样即使主线程正处于嵌套 RunLoop（例如模态弹窗、单元测试等待）中也能及时收到通知。
nonisolated final class ProfileDirectoryMonitor: @unchecked Sendable {
    private let directories: [URL]
    private let debounceInterval: TimeInterval
    private let onChange: () -> Void
    private let queue = DispatchQueue(label: "cn.vanjay.ProfileSmith.directory-monitor")
    private var sources: [DispatchSourceFileSystemObject] = []
    private var pendingNotification: DispatchWorkItem?
    private var running = false

    /// - Parameter onChange: 在主线程回调。
    init(directories: [URL], debounceInterval: TimeInterval = 0.8, onChange: @escaping () -> Void) {
        self.directories = directories
        self.debounceInterval = debounceInterval
        self.onChange = onChange
    }

    deinit {
        sources.forEach { $0.cancel() }
    }

    var isRunning: Bool {
        queue.sync { running }
    }

    func start() {
        queue.sync {
            guard !running else { return }
            running = true
            rearm()
        }
    }

    func stop() {
        queue.sync {
            running = false
            pendingNotification?.cancel()
            pendingNotification = nil
            sources.forEach { $0.cancel() }
            sources.removeAll()
        }
    }

    /// 当前应被监听的目录，便于测试验证目录不存在时的回退逻辑。
    var monitoredPaths: [String] {
        Self.uniqueWatchTargets(for: directories).map(\.path)
    }

    /// 只能在 queue 上调用。
    private func rearm() {
        sources.forEach { $0.cancel() }
        sources.removeAll()

        for directory in Self.uniqueWatchTargets(for: directories) {
            let descriptor = open(directory.path, O_EVTONLY)
            guard descriptor >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .delete, .rename, .extend, .link],
                queue: queue
            )
            source.setEventHandler { [weak self] in
                self?.scheduleNotification()
            }
            source.setCancelHandler {
                close(descriptor)
            }
            source.resume()
            sources.append(source)
        }
    }

    /// 只能在 queue 上调用。
    private func scheduleNotification() {
        guard running else { return }
        pendingNotification?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.running else { return }
            // 目录可能刚被创建或删除，重新挂载监听后再通知外部刷新。
            self.rearm()
            let onChange = self.onChange
            RunLoop.main.perform {
                onChange()
            }
            // 主线程可能正阻塞在 RunLoop 之外的等待中，唤醒一次确保回调尽快执行。
            CFRunLoopWakeUp(CFRunLoopGetMain())
        }
        pendingNotification = workItem
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    private static func uniqueWatchTargets(for directories: [URL]) -> [URL] {
        var seen = Set<String>()
        var targets: [URL] = []
        for directory in directories {
            guard let target = nearestExistingDirectory(for: directory) else { continue }
            if seen.insert(target.path).inserted {
                targets.append(target)
            }
        }
        return targets
    }

    private static func nearestExistingDirectory(for url: URL) -> URL? {
        var candidate = url.standardizedFileURL
        let fileManager = FileManager.default
        while true {
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }
            let parent = candidate.deletingLastPathComponent()
            if parent.path == candidate.path {
                return nil
            }
            candidate = parent
        }
    }
}
