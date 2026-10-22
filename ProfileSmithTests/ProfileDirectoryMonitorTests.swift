import Foundation
import Testing
@testable import ProfileSmith

@Suite(.serialized)
struct ProfileDirectoryMonitorTests {
    @MainActor
    @Test
    func notifiesOnceAfterBurstOfFileChanges() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let watchedDirectory = try temporaryDirectory.makeDirectory(named: "Profiles")
        var notificationCount = 0
        let monitor = ProfileDirectoryMonitor(directories: [watchedDirectory], debounceInterval: 0.2) {
            notificationCount += 1
        }
        monitor.start()
        defer { monitor.stop() }

        // 连续写入多个文件，防抖后应只触发一次刷新。
        for index in 0..<3 {
            try Data("\(index)".utf8).write(to: watchedDirectory.appendingPathComponent("\(index).mobileprovision"))
        }

        try waitUntil(description: "monitor notification") { notificationCount >= 1 }
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        #expect(notificationCount == 1)
    }

    @MainActor
    @Test
    func watchesNearestExistingParentUntilDirectoryIsCreated() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let missingDirectory = temporaryDirectory.url.appendingPathComponent("Provisioning Profiles", isDirectory: true)
        var notificationCount = 0
        let monitor = ProfileDirectoryMonitor(directories: [missingDirectory], debounceInterval: 0.1) {
            notificationCount += 1
        }
        #expect(monitor.monitoredPaths == [temporaryDirectory.url.standardizedFileURL.path])

        monitor.start()
        defer { monitor.stop() }

        try FileManager.default.createDirectory(at: missingDirectory, withIntermediateDirectories: true)
        try waitUntil(description: "parent directory notification") { notificationCount >= 1 }
        #expect(monitor.monitoredPaths == [missingDirectory.standardizedFileURL.path])

        // 目录创建后已切换为直接监听目标目录，其中的新文件同样能触发刷新。
        let countBeforeWrite = notificationCount
        try Data("x".utf8).write(to: missingDirectory.appendingPathComponent("new.mobileprovision"))
        try waitUntil(description: "target directory notification") { notificationCount > countBeforeWrite }
    }

    @MainActor
    @Test
    func stoppedMonitorDoesNotNotify() throws {
        let temporaryDirectory = try TestTemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        var notificationCount = 0
        let monitor = ProfileDirectoryMonitor(directories: [temporaryDirectory.url], debounceInterval: 0.1) {
            notificationCount += 1
        }
        monitor.start()
        monitor.stop()

        try Data("x".utf8).write(to: temporaryDirectory.url.appendingPathComponent("after-stop.mobileprovision"))
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        #expect(notificationCount == 0)
        #expect(!monitor.isRunning)
    }
}

@MainActor
private func waitUntil(timeout: TimeInterval = 5, description: String, condition: () -> Bool) throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() {
            return
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
    if !condition() {
        throw NSError(
            domain: "ProfileSmithTests.Timeout",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Condition '\(description)' was not satisfied within \(timeout) seconds."]
        )
    }
}
