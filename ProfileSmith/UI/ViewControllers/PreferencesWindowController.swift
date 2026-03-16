import AppKit
import Combine
import SnapKit

@MainActor
final class PreferencesWindowController: NSWindowController {
    private static let autosaveName = NSWindow.FrameAutosaveName("ProfileSmithPreferencesWindowFrame")

    init(updateManager: UpdateManager, settings: AppSettings? = nil) {
        let resolvedSettings = settings ?? AppSettings.shared
        let contentViewController = PreferencesViewController(updateManager: updateManager, settings: resolvedSettings)
        let window = NSWindow(contentViewController: contentViewController)
        window.title = "偏好设置"
        window.styleMask = [.titled, .closable, .miniaturizable]
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .preference
        }
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.setContentSize(NSSize(width: 560, height: 320))
        window.minSize = NSSize(width: 560, height: 320)
        super.init(window: window)
        shouldCascadeWindows = false

        if !window.setFrameUsingName(Self.autosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.autosaveName)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showPreferencesWindow() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

@MainActor
private final class PreferencesViewController: NSViewController {
    private let updateManager: UpdateManager
    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    private var updateStrategyPopup: NSPopUpButton!
    private var automaticDownloadsCheckbox: NSButton!
    private var automaticDownloadsHintLabel: NSTextField!
    private var versionLabel: NSTextField!

    init(updateManager: UpdateManager, settings: AppSettings) {
        self.updateManager = updateManager
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        buildUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindSettings()
        syncControlsFromSettings()
    }

    private func buildUI() {
        let titleLabel = NSTextField(labelWithString: "更新")
        titleLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 26) ?? .systemFont(ofSize: 26, weight: .semibold)

        let descriptionLabel = NSTextField(wrappingLabelWithString: "控制 ProfileSmith 的更新检查方式。Sparkle 可用时会直接应用到内建更新器；否则会回退到 GitHub Releases。")
        descriptionLabel.textColor = .secondaryLabelColor

        let card = NSView()
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor.separatorColor.cgColor

        let contentStack = NSStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 14

        contentStack.addArrangedSubview(makeLabeledRow(title: "检查策略", control: makeUpdateStrategyControl()))
        contentStack.addArrangedSubview(makeAutomaticDownloadsRow())
        contentStack.addArrangedSubview(makeAutomaticDownloadsHint())
        contentStack.addArrangedSubview(makeActionsRow())

        card.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(18)
        }

        versionLabel = NSTextField(labelWithString: currentVersionDescription)
        versionLabel.textColor = .secondaryLabelColor

        let rootStack = NSStackView(views: [titleLabel, descriptionLabel, card, versionLabel])
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 16

        view.addSubview(rootStack)
        rootStack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(22)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.lessThanOrEqualToSuperview().inset(22)
        }

        card.snp.makeConstraints { make in
            make.width.equalTo(rootStack)
        }
    }

    private func bindSettings() {
        settings.$updateCheckStrategy
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncControlsFromSettings()
            }
            .store(in: &cancellables)
    }

    private func syncControlsFromSettings() {
        if let index = UpdateCheckStrategy.allCases.firstIndex(of: settings.updateCheckStrategy) {
            updateStrategyPopup.selectItem(at: index)
        }

        automaticDownloadsCheckbox.state = updateManager.automaticallyDownloadsUpdates ? .on : .off

        let automaticDownloadsAvailable = updateManager.supportsAutomaticUpdateDownloads
        let strategyAllowsBackgroundUpdates = settings.updateCheckStrategy != .manual
        automaticDownloadsCheckbox.isEnabled = automaticDownloadsAvailable && strategyAllowsBackgroundUpdates

        if !automaticDownloadsAvailable {
            automaticDownloadsHintLabel.stringValue = "当前构建未启用 Sparkle 自动下载能力。"
        } else if strategyAllowsBackgroundUpdates {
            automaticDownloadsHintLabel.stringValue = "检测到新版本后可在后台自动下载，重启应用时安装。"
        } else {
            automaticDownloadsHintLabel.stringValue = "手动检查模式下不会在后台自动下载更新。"
        }

        versionLabel.stringValue = currentVersionDescription
    }

    private func makeLabeledRow(title: String, control: NSView) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.alignment = .right
        titleLabel.font = .systemFont(ofSize: NSFont.systemFontSize)
        titleLabel.snp.makeConstraints { make in
            make.width.equalTo(92)
        }

        let row = NSStackView(views: [titleLabel, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func makeUpdateStrategyControl() -> NSView {
        updateStrategyPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        updateStrategyPopup.addItems(withTitles: UpdateCheckStrategy.allCases.map(\.title))
        updateStrategyPopup.target = self
        updateStrategyPopup.action = #selector(updateStrategyChanged(_:))
        return updateStrategyPopup
    }

    private func makeAutomaticDownloadsRow() -> NSView {
        automaticDownloadsCheckbox = NSButton(checkboxWithTitle: "自动下载更新", target: self, action: #selector(toggleAutomaticDownloads(_:)))
        automaticDownloadsCheckbox.font = .systemFont(ofSize: NSFont.systemFontSize)

        let spacer = NSView()
        spacer.snp.makeConstraints { make in
            make.width.equalTo(92)
        }

        let row = NSStackView(views: [spacer, automaticDownloadsCheckbox])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func makeAutomaticDownloadsHint() -> NSView {
        automaticDownloadsHintLabel = NSTextField(wrappingLabelWithString: "")
        automaticDownloadsHintLabel.textColor = .secondaryLabelColor
        automaticDownloadsHintLabel.maximumNumberOfLines = 2

        let spacer = NSView()
        spacer.snp.makeConstraints { make in
            make.width.equalTo(92)
        }

        let row = NSStackView(views: [spacer, automaticDownloadsHintLabel])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 12
        return row
    }

    private func makeActionsRow() -> NSView {
        let checkNowButton = NSButton(title: "立即检查更新", target: self, action: #selector(checkForUpdates(_:)))
        let openGitHubButton = NSButton(title: "打开 GitHub", target: self, action: #selector(openGitHubHomepage(_:)))

        let buttons = NSStackView(views: [checkNowButton, openGitHubButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 10

        let spacer = NSView()
        spacer.snp.makeConstraints { make in
            make.width.equalTo(92)
        }

        let row = NSStackView(views: [spacer, buttons])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private var currentVersionDescription: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "当前版本 \(shortVersion) (\(buildVersion))"
    }

    @objc private func updateStrategyChanged(_ sender: NSPopUpButton) {
        let selectedIndex = max(0, sender.indexOfSelectedItem)
        guard UpdateCheckStrategy.allCases.indices.contains(selectedIndex) else { return }
        settings.updateCheckStrategy = UpdateCheckStrategy.allCases[selectedIndex]
    }

    @objc private func toggleAutomaticDownloads(_ sender: NSButton) {
        updateManager.automaticallyDownloadsUpdates = sender.state == .on
        syncControlsFromSettings()
    }

    @objc private func checkForUpdates(_ sender: Any?) {
        updateManager.checkForUpdates()
    }

    @objc private func openGitHubHomepage(_ sender: Any?) {
        updateManager.openGitHubHomepage()
    }
}
