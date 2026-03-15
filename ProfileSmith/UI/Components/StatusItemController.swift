import Cocoa
import Combine

final class StatusItemController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let repository: ProfileRepository
    private let updateManager: UpdateManager
    private let quickLookPluginManager: QuickLookPluginManager
    private let openMainWindowHandler: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(
        repository: ProfileRepository,
        updateManager: UpdateManager,
        quickLookPluginManager: QuickLookPluginManager,
        openMainWindowHandler: @escaping () -> Void
    ) {
        self.repository = repository
        self.updateManager = updateManager
        self.quickLookPluginManager = quickLookPluginManager
        self.openMainWindowHandler = openMainWindowHandler

        configureStatusItem()
        bindRepository()
    }

    private func configureStatusItem() {
        statusItem.button?.title = "PS"
        statusItem.button?.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
        rebuildMenu(with: repository.snapshot)
    }

    private func bindRepository() {
        repository.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.rebuildMenu(with: snapshot)
            }
            .store(in: &cancellables)
    }

    private func rebuildMenu(with snapshot: RepositorySnapshot) {
        let menu = NSMenu()

        let summaryItem = NSMenuItem(title: "已索引 \(snapshot.metrics.totalCount) 个描述文件", action: nil, keyEquivalent: "")
        summaryItem.isEnabled = false
        menu.addItem(summaryItem)

        let warningItem = NSMenuItem(title: "已过期 \(snapshot.metrics.expiredCount) 个，30 天内到期 \(snapshot.metrics.expiringSoonCount) 个", action: nil, keyEquivalent: "")
        warningItem.isEnabled = false
        menu.addItem(warningItem)
        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "打开 ProfileSmith", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let refreshItem = NSMenuItem(title: "刷新索引", action: #selector(refresh), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let quickLookTitle = quickLookPluginManager.isInstalled ? "卸载 Finder Quick Look 插件" : "安装 Finder Quick Look 插件"
        let quickLookItem = NSMenuItem(title: quickLookTitle, action: #selector(toggleQuickLookPlugin), keyEquivalent: "")
        quickLookItem.target = self
        menu.addItem(quickLookItem)

        let updateItem = NSMenuItem(title: "检查更新…", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quitItem.target = NSApp
        menu.addItem(quitItem)

        statusItem.button?.title = snapshot.metrics.expiredCount > 0 ? "PS !\(snapshot.metrics.expiredCount)" : "PS"
        statusItem.menu = menu
    }

    @objc private func openMainWindow() {
        openMainWindowHandler()
    }

    @objc private func refresh() {
        repository.refresh(forceReindex: false)
    }

    @objc private func toggleQuickLookPlugin() {
        do {
            if quickLookPluginManager.isInstalled {
                try quickLookPluginManager.uninstallPlugin()
            } else {
                try quickLookPluginManager.installBundledPlugin()
            }
            rebuildMenu(with: repository.snapshot)
        } catch {
            NSApp.presentError(error)
        }
    }

    @objc private func checkForUpdates() {
        updateManager.checkForUpdates()
    }
}
