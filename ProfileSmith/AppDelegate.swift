import Cocoa

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var context: AppContext?
    private var mainWindowController: MainWindowController?
    private var statusItemController: StatusItemController?
    private let environment = ProcessInfo.processInfo.environment

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let context = try AppContext()
            self.context = context

            buildMainMenu()

            let mainWindowController = MainWindowController(context: context)
            self.mainWindowController = mainWindowController
            mainWindowController.showWindow(nil)

            if !isUITesting {
                let statusItemController = StatusItemController(
                    repository: context.repository,
                    updateManager: context.updateManager,
                    quickLookPluginManager: context.quickLookPluginManager
                ) { [weak self] in
                    self?.openMainWindow(nil)
                }
                self.statusItemController = statusItemController
            }

            context.repository.start()
            if !isUITesting {
                context.updateManager.configure()
                context.updateManager.scheduleBackgroundUpdateCheck()
            }
        } catch {
            presentFatalError(error)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController = nil
        mainWindowController = nil
        context?.invalidate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else { return true }
        openMainWindow(nil)
        return true
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        openMainWindow(nil)
        mainWindowController?.contentController.handleExternalFiles(urls)
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
        false
    }

    @objc private func openMainWindow(_ sender: Any?) {
        guard let mainWindowController else { return }
        mainWindowController.showWindow(sender)
        mainWindowController.window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func refreshProfiles(_ sender: Any?) {
        context?.repository.refresh(forceReindex: false)
    }

    @objc private func importProfiles(_ sender: Any?) {
        mainWindowController?.contentController.presentImportPanel(sender)
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        context?.updateManager.checkForUpdates()
    }

    @objc private func openQuickLookPluginManager(_ sender: Any?) {
        mainWindowController?.contentController.presentQuickLookPluginPanel(sender)
    }

    @objc private func openGitHubHomepage(_ sender: Any?) {
        context?.updateManager.openGitHubHomepage()
    }

    private var isUITesting: Bool {
        environment["PROFILESMITH_UI_TEST"] == "1"
    }

    private func presentFatalError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.messageText = "ProfileSmith 启动失败"
        alert.informativeText = error.localizedDescription
        alert.runModal()
        NSApp.terminate(nil)
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            NSMenuItem(
                title: "关于 ProfileSmith",
                action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                keyEquivalent: ""
            )
        )
        let updateItem = NSMenuItem(title: "检查更新…", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = self
        appMenu.addItem(updateItem)
        appMenu.addItem(NSMenuItem.separator())
        let pluginItem = NSMenuItem(title: "Quick Look 插件…", action: #selector(openQuickLookPluginManager(_:)), keyEquivalent: "")
        pluginItem.target = self
        appMenu.addItem(pluginItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "隐藏 ProfileSmith", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: "显示全部", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: "退出 ProfileSmith", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        let importItem = NSMenuItem(title: "导入描述文件…", action: #selector(importProfiles(_:)), keyEquivalent: "o")
        importItem.target = self
        fileMenu.addItem(importItem)
        let refreshItem = NSMenuItem(title: "刷新", action: #selector(refreshProfiles(_:)), keyEquivalent: "r")
        refreshItem.keyEquivalentModifierMask = [.command]
        refreshItem.target = self
        fileMenu.addItem(refreshItem)
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(NSMenuItem(title: "关闭窗口", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileItem.submenu = fileMenu
        fileItem.title = "文件"
        mainMenu.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "重做", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        editItem.title = "编辑"
        mainMenu.addItem(editItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "视图")
        let revealItem = NSMenuItem(title: "显示主窗口", action: #selector(openMainWindow(_:)), keyEquivalent: "1")
        revealItem.keyEquivalentModifierMask = [.command]
        revealItem.target = self
        viewMenu.addItem(revealItem)
        viewItem.submenu = viewMenu
        viewItem.title = "视图"
        mainMenu.addItem(viewItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(NSMenuItem(title: "最小化", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "缩放", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        NSApp.windowsMenu = windowMenu
        windowItem.submenu = windowMenu
        windowItem.title = "窗口"
        mainMenu.addItem(windowItem)

        let helpItem = NSMenuItem()
        let helpMenu = NSMenu(title: "帮助")
        let homeItem = NSMenuItem(title: "ProfileSmith GitHub 主页", action: #selector(openGitHubHomepage(_:)), keyEquivalent: "?")
        homeItem.target = self
        helpMenu.addItem(homeItem)
        helpItem.submenu = helpMenu
        helpItem.title = "帮助"
        mainMenu.addItem(helpItem)

        NSApp.mainMenu = mainMenu
    }
}
