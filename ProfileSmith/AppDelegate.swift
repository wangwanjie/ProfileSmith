import Cocoa
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var context: AppContext?
    private var mainWindowController: MainWindowController?
    private var preferencesWindowController: PreferencesWindowController?
    private var statusItemController: StatusItemController?
    private var hasPresentedInitialWindow = false
    private let environment = ProcessInfo.processInfo.environment
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            NSApp.setActivationPolicy(.regular)
            let context = try AppContext()
            self.context = context

            buildMainMenu()
            bindLocalization()

            let mainWindowController = MainWindowController(context: context)
            self.mainWindowController = mainWindowController
            // Ensure repository observers are attached before the first launch refresh starts.
            _ = mainWindowController.contentController.view
            preferencesWindowController = PreferencesWindowController(updateManager: context.updateManager)

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

            DispatchQueue.main.async { [weak self] in
                self?.presentInitialMainWindowIfNeeded()
            }
        } catch {
            presentFatalError(error)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        presentInitialMainWindowIfNeeded()
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
        activateAppBringingAllWindowsForward()
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
        hasPresentedInitialWindow = true
        guard let mainWindowController else { return }
        present(mainWindowController: mainWindowController, sender: sender)
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

    @objc private func openPreferencesWindow(_ sender: Any?) {
        preferencesWindowController?.showPreferencesWindow()
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

    private func presentInitialMainWindowIfNeeded() {
        guard !hasPresentedInitialWindow else { return }
        guard let mainWindowController else { return }

        hasPresentedInitialWindow = true
        present(mainWindowController: mainWindowController, sender: nil)
    }

    private func present(mainWindowController: MainWindowController, sender: Any?) {
        mainWindowController.showWindow(sender)
        mainWindowController.window?.deminiaturize(sender)
        mainWindowController.window?.setIsVisible(true)
        mainWindowController.window?.makeMain()
        mainWindowController.window?.makeKey()
        mainWindowController.window?.makeKeyAndOrderFront(sender)
        mainWindowController.window?.orderFrontRegardless()
        activateAppBringingAllWindowsForward()
    }

    private func activateAppBringingAllWindowsForward() {
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func presentFatalError(_ error: Error) {
        NSApp.setActivationPolicy(.regular)
        activateAppBringingAllWindowsForward()
        let alert = NSAlert(error: error)
        alert.messageText = L10n.fatalLaunchTitle
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
                title: L10n.menuAbout,
                action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                keyEquivalent: ""
            )
        )
        let preferencesItem = NSMenuItem(title: L10n.menuPreferences, action: #selector(openPreferencesWindow(_:)), keyEquivalent: ",")
        preferencesItem.target = self
        appMenu.addItem(preferencesItem)
        let updateItem = NSMenuItem(title: L10n.menuCheckForUpdates, action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = self
        appMenu.addItem(updateItem)
        appMenu.addItem(NSMenuItem.separator())
        let pluginItem = NSMenuItem(title: L10n.menuFinderQuickLook, action: #selector(openQuickLookPluginManager(_:)), keyEquivalent: "")
        pluginItem.target = self
        appMenu.addItem(pluginItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: L10n.menuHideApp, action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: L10n.menuHideOthers, action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h"))
        appMenu.addItem(NSMenuItem(title: L10n.menuShowAll, action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(NSMenuItem(title: L10n.menuQuitApp, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: L10n.menuFile)
        let importItem = NSMenuItem(title: L10n.menuImportProfiles, action: #selector(importProfiles(_:)), keyEquivalent: "o")
        importItem.target = self
        fileMenu.addItem(importItem)
        let refreshItem = NSMenuItem(title: L10n.menuRefresh, action: #selector(refreshProfiles(_:)), keyEquivalent: "r")
        refreshItem.keyEquivalentModifierMask = [.command]
        refreshItem.target = self
        fileMenu.addItem(refreshItem)
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(NSMenuItem(title: L10n.menuCloseWindow, action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileItem.submenu = fileMenu
        fileItem.title = L10n.menuFile
        mainMenu.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: L10n.menuEdit)
        editMenu.addItem(NSMenuItem(title: L10n.menuUndo, action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: L10n.menuRedo, action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: L10n.menuCut, action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: L10n.menuCopy, action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: L10n.menuPaste, action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: L10n.menuSelectAll, action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        editItem.title = L10n.menuEdit
        mainMenu.addItem(editItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: L10n.menuView)
        let revealItem = NSMenuItem(title: L10n.menuShowMainWindow, action: #selector(openMainWindow(_:)), keyEquivalent: "1")
        revealItem.keyEquivalentModifierMask = [.command]
        revealItem.target = self
        viewMenu.addItem(revealItem)
        viewItem.submenu = viewMenu
        viewItem.title = L10n.menuView
        mainMenu.addItem(viewItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: L10n.menuWindow)
        windowMenu.addItem(NSMenuItem(title: L10n.menuMinimize, action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: L10n.menuZoom, action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        NSApp.windowsMenu = windowMenu
        windowItem.submenu = windowMenu
        windowItem.title = L10n.menuWindow
        mainMenu.addItem(windowItem)

        let helpItem = NSMenuItem()
        let helpMenu = NSMenu(title: L10n.menuHelp)
        let homeItem = NSMenuItem(title: L10n.menuGitHubHomepage, action: #selector(openGitHubHomepage(_:)), keyEquivalent: "?")
        homeItem.target = self
        helpMenu.addItem(homeItem)
        helpItem.submenu = helpMenu
        helpItem.title = L10n.menuHelp
        mainMenu.addItem(helpItem)

        NSApp.mainMenu = mainMenu
    }

    private func bindLocalization() {
        guard cancellables.isEmpty else { return }
        AppLocalization.shared.$language
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.buildMainMenu()
            }
            .store(in: &cancellables)
    }
}
