import Cocoa
import Combine

enum StatusItemMenuAction {
    case openMainWindow
    case refresh
    case toggleQuickLookPlugin
    case checkForUpdates
    case quit
}

struct StatusItemMenuEntry {
    let title: String
    let action: StatusItemMenuAction?
    let isEnabled: Bool
    let isSeparator: Bool

    init(title: String, action: StatusItemMenuAction?, isEnabled: Bool = true) {
        self.title = title
        self.action = action
        self.isEnabled = isEnabled
        self.isSeparator = false
    }

    private init(isSeparator: Bool) {
        self.title = ""
        self.action = nil
        self.isEnabled = false
        self.isSeparator = isSeparator
    }

    static let separator = StatusItemMenuEntry(isSeparator: true)
}

struct StatusItemMenuContent {
    let buttonTitle: String
    let entries: [StatusItemMenuEntry]

    init(snapshot: RepositorySnapshot, quickLookButtonTitle: String, quickLookAvailable: Bool) {
        buttonTitle = snapshot.metrics.expiredCount > 0 ? "PS !\(snapshot.metrics.expiredCount)" : "PS"
        entries = [
            StatusItemMenuEntry(title: L10n.statusIndexed(snapshot.metrics.totalCount), action: nil, isEnabled: false),
            StatusItemMenuEntry(
                title: L10n.statusWarning(expired: snapshot.metrics.expiredCount, expiringSoon: snapshot.metrics.expiringSoonCount),
                action: nil,
                isEnabled: false
            ),
            .separator,
            StatusItemMenuEntry(title: L10n.statusOpen, action: .openMainWindow),
            StatusItemMenuEntry(title: L10n.statusRefresh, action: .refresh),
            StatusItemMenuEntry(title: quickLookButtonTitle, action: .toggleQuickLookPlugin, isEnabled: quickLookAvailable),
            StatusItemMenuEntry(title: L10n.statusCheckForUpdates, action: .checkForUpdates),
            .separator,
            StatusItemMenuEntry(title: L10n.statusQuit, action: .quit),
        ]
    }

    var visibleTitles: [String] {
        entries.filter { !$0.isSeparator }.map(\.title)
    }
}

@MainActor
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

        AppLocalization.shared.$language
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.rebuildMenu(with: self.repository.snapshot)
            }
            .store(in: &cancellables)
    }

    private func rebuildMenu(with snapshot: RepositorySnapshot) {
        let content = StatusItemMenuContent(
            snapshot: snapshot,
            quickLookButtonTitle: quickLookPluginManager.buttonTitle,
            quickLookAvailable: quickLookPluginManager.isAvailable
        )
        let menu = NSMenu()

        for entry in content.entries {
            if entry.isSeparator {
                menu.addItem(NSMenuItem.separator())
                continue
            }

            let item = NSMenuItem(title: entry.title, action: selector(for: entry.action), keyEquivalent: "")
            item.target = target(for: entry.action)
            item.isEnabled = entry.isEnabled
            menu.addItem(item)
        }

        statusItem.button?.title = content.buttonTitle
        statusItem.menu = menu
    }

    private func selector(for action: StatusItemMenuAction?) -> Selector? {
        switch action {
        case .openMainWindow:
            return #selector(openMainWindow)
        case .refresh:
            return #selector(refresh)
        case .toggleQuickLookPlugin:
            return #selector(toggleQuickLookPlugin)
        case .checkForUpdates:
            return #selector(checkForUpdates)
        case .quit:
            return #selector(NSApplication.terminate(_:))
        case nil:
            return nil
        }
    }

    private func target(for action: StatusItemMenuAction?) -> AnyObject? {
        switch action {
        case .quit:
            return NSApp
        case .openMainWindow, .refresh, .toggleQuickLookPlugin, .checkForUpdates:
            return self
        case nil:
            return nil
        }
    }

    @objc private func openMainWindow() {
        openMainWindowHandler()
    }

    @objc private func refresh() {
        repository.refresh(forceReindex: false)
    }

    @objc private func toggleQuickLookPlugin() {
        do {
            try quickLookPluginManager.refreshRegistration()
            rebuildMenu(with: repository.snapshot)
        } catch {
            NSApp.presentError(error)
        }
    }

    @objc private func checkForUpdates() {
        updateManager.checkForUpdates()
    }
}
