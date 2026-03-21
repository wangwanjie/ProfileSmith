import AppKit
import Combine
import SnapKit

@MainActor
final class PreferencesWindowController: NSWindowController {
    private static let autosaveName = NSWindow.FrameAutosaveName("ProfileSmithPreferencesWindowFrame")
    private var cancellables = Set<AnyCancellable>()

    init(updateManager: UpdateManager, settings: AppSettings? = nil) {
        let resolvedSettings = settings ?? AppSettings.shared
        let contentViewController = PreferencesViewController(updateManager: updateManager, settings: resolvedSettings)
        let window = NSWindow(contentViewController: contentViewController)
        window.title = L10n.preferencesWindowTitle
        window.styleMask = [.titled, .closable, .miniaturizable]
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .preference
        }
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.tabbingMode = .disallowed
        window.setContentSize(NSSize(width: 640, height: 420))
        window.minSize = NSSize(width: 640, height: 420)
        super.init(window: window)
        shouldCascadeWindows = false

        if !window.setFrameUsingName(Self.autosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.autosaveName)
        bindLocalization()
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

    private func bindLocalization() {
        AppLocalization.shared.$language
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.window?.title = L10n.preferencesWindowTitle
            }
            .store(in: &cancellables)
    }

    var debugLanguagePopup: NSPopUpButton {
        preferencesViewController.debugLanguagePopup
    }

    var debugAppearancePopup: NSPopUpButton {
        preferencesViewController.debugAppearancePopup
    }

    var debugCheckForUpdatesButtonTitle: String {
        preferencesViewController.debugCheckForUpdatesButtonTitle
    }

    var debugOpenGitHubButtonTitle: String {
        preferencesViewController.debugOpenGitHubButtonTitle
    }

    var debugCardBackgroundColor: NSColor? {
        preferencesViewController.debugCardBackgroundColor
    }

    var debugEffectiveAppearance: NSAppearance {
        preferencesViewController.view.effectiveAppearance
    }

    private var preferencesViewController: PreferencesViewController {
        window?.contentViewController as! PreferencesViewController
    }
}

@MainActor
final class PreferencesViewController: NSViewController {
    private enum PreferencesPane: Int, CaseIterable {
        case general
        case updates
    }

    private let updateManager: UpdateManager
    private let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()
    private var selectedPane: PreferencesPane = .general

    private let titleLabel = NSTextField(labelWithString: "")
    private let descriptionLabel = NSTextField(wrappingLabelWithString: "")
    private let sectionControl = NSSegmentedControl(labels: ["", ""], trackingMode: .selectOne, target: nil, action: nil)
    private let card = NSView()
    private let paneHostView = NSView()
    private let generalPaneView = NSView()
    private let updatesPaneView = NSView()
    private let languageTitleLabel = NSTextField(labelWithString: "")
    private let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let appearanceTitleLabel = NSTextField(labelWithString: "")
    private let appearancePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let updateChecksTitleLabel = NSTextField(labelWithString: "")
    private var updateStrategyPopup: NSPopUpButton!
    private var automaticDownloadsCheckbox: NSButton!
    private var automaticDownloadsHintLabel: NSTextField!
    private var versionLabel: NSTextField!
    private var checkNowButton: NSButton!
    private var openGitHubButton: NSButton!

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
        let appearanceAwareView = AppearanceAwareView()
        appearanceAwareView.onEffectiveAppearanceChange = { [weak self] in
            self?.updateAppearanceColors()
        }
        view = appearanceAwareView
        buildUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindSettings()
        applyLocalization()
        syncControlsFromSettings()
        updateAppearanceColors()
    }

    private func buildUI() {
        titleLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 26) ?? .systemFont(ofSize: 26, weight: .semibold)

        descriptionLabel.textColor = .secondaryLabelColor

        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.borderWidth = 1
        sectionControl.segmentStyle = .rounded
        sectionControl.selectedSegment = selectedPane.rawValue
        sectionControl.target = self
        sectionControl.action = #selector(changePane(_:))

        languagePopup.target = self
        languagePopup.action = #selector(languageChanged(_:))
        appearancePopup.target = self
        appearancePopup.action = #selector(appearanceChanged(_:))

        let generalContentStack = NSStackView(views: [
            makeLabeledRow(titleLabel: languageTitleLabel, control: languagePopup),
            makeLabeledRow(titleLabel: appearanceTitleLabel, control: appearancePopup)
        ])
        generalContentStack.orientation = .vertical
        generalContentStack.alignment = .leading
        generalContentStack.spacing = 14
        generalPaneView.addSubview(generalContentStack)
        generalContentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let updatesContentStack = NSStackView(views: [
            makeLabeledRow(titleLabel: updateChecksTitleLabel, control: makeUpdateStrategyControl()),
            makeAutomaticDownloadsRow(),
            makeAutomaticDownloadsHint(),
            makeActionsRow()
        ])
        updatesContentStack.orientation = .vertical
        updatesContentStack.alignment = .leading
        updatesContentStack.spacing = 14
        updatesPaneView.addSubview(updatesContentStack)
        updatesContentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        card.addSubview(paneHostView)
        paneHostView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(18)
        }

        versionLabel = NSTextField(labelWithString: "")
        versionLabel.textColor = .secondaryLabelColor

        let rootStack = NSStackView(views: [titleLabel, descriptionLabel, sectionControl, card, versionLabel])
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
        sectionControl.snp.makeConstraints { make in
            make.width.equalTo(280)
        }

        presentSelectedPane()
    }

    private func bindSettings() {
        settings.$appLanguage
            .combineLatest(settings.$appAppearance, settings.$updateCheckStrategy)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.syncControlsFromSettings()
            }
            .store(in: &cancellables)

        AppLocalization.shared.$language
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyLocalization()
                self?.syncControlsFromSettings()
            }
            .store(in: &cancellables)
    }

    private func syncControlsFromSettings() {
        if let languageIndex = AppLanguage.allCases.firstIndex(of: settings.appLanguage) {
            languagePopup.selectItem(at: languageIndex)
        }
        if let appearanceIndex = AppAppearance.allCases.firstIndex(of: settings.appAppearance) {
            appearancePopup.selectItem(at: appearanceIndex)
        }
        if let index = UpdateCheckStrategy.allCases.firstIndex(of: settings.updateCheckStrategy) {
            updateStrategyPopup.selectItem(at: index)
        }

        automaticDownloadsCheckbox.state = updateManager.automaticallyDownloadsUpdates ? .on : .off

        let automaticDownloadsAvailable = updateManager.supportsAutomaticUpdateDownloads
        let strategyAllowsBackgroundUpdates = settings.updateCheckStrategy != .manual
        automaticDownloadsCheckbox.isEnabled = automaticDownloadsAvailable && strategyAllowsBackgroundUpdates

        if !automaticDownloadsAvailable {
            automaticDownloadsHintLabel.stringValue = L10n.preferencesAutoDownloadsUnavailable
        } else if strategyAllowsBackgroundUpdates {
            automaticDownloadsHintLabel.stringValue = L10n.preferencesAutoDownloadsAvailable
        } else {
            automaticDownloadsHintLabel.stringValue = L10n.preferencesAutoDownloadsUnavailable
        }

        versionLabel.stringValue = currentVersionDescription
    }

    private func applyLocalization() {
        titleLabel.stringValue = L10n.preferencesTitle
        descriptionLabel.stringValue = L10n.preferencesDescription
        sectionControl.setLabel(L10n.preferencesSegmentGeneral, forSegment: PreferencesPane.general.rawValue)
        sectionControl.setLabel(L10n.preferencesSegmentUpdates, forSegment: PreferencesPane.updates.rawValue)
        languageTitleLabel.stringValue = L10n.preferencesLanguage
        appearanceTitleLabel.stringValue = L10n.preferencesAppearance
        updateChecksTitleLabel.stringValue = L10n.preferencesUpdateChecks
        automaticDownloadsCheckbox.title = L10n.preferencesAutoDownloads
        checkNowButton.title = L10n.preferencesCheckForUpdates
        openGitHubButton.title = L10n.preferencesOpenGitHub
        rebuildLanguagePopup()
        rebuildAppearancePopup()
        rebuildUpdateStrategyPopup()
    }

    private func updateAppearanceColors() {
        card.layer?.backgroundColor = resolvedCGColor(NSColor.controlBackgroundColor, appearance: view.effectiveAppearance)
        card.layer?.borderColor = resolvedCGColor(NSColor.separatorColor, appearance: view.effectiveAppearance)
    }

    private func makeLabeledRow(titleLabel: NSTextField, control: NSView) -> NSView {
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
        updateStrategyPopup.target = self
        updateStrategyPopup.action = #selector(updateStrategyChanged(_:))
        return updateStrategyPopup
    }

    private func makeAutomaticDownloadsRow() -> NSView {
        automaticDownloadsCheckbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleAutomaticDownloads(_:)))
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
        checkNowButton = NSButton(title: L10n.preferencesCheckForUpdates, target: self, action: #selector(checkForUpdates(_:)))
        openGitHubButton = NSButton(title: L10n.preferencesOpenGitHub, target: self, action: #selector(openGitHubHomepage(_:)))

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
        return L10n.currentVersion(shortVersion, buildVersion)
    }

    private func presentSelectedPane() {
        paneHostView.subviews.forEach { $0.removeFromSuperview() }

        let paneView: NSView
        switch selectedPane {
        case .general:
            paneView = generalPaneView
        case .updates:
            paneView = updatesPaneView
        }

        paneHostView.addSubview(paneView)
        paneView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func rebuildLanguagePopup() {
        languagePopup.removeAllItems()
        languagePopup.addItems(withTitles: AppLanguage.allCases.map(L10n.languageName))
    }

    private func rebuildAppearancePopup() {
        appearancePopup.removeAllItems()
        appearancePopup.addItems(withTitles: AppAppearance.allCases.map(L10n.appearanceName))
    }

    private func rebuildUpdateStrategyPopup() {
        updateStrategyPopup.removeAllItems()
        updateStrategyPopup.addItems(withTitles: UpdateCheckStrategy.allCases.map(\.title))
    }

    @objc private func updateStrategyChanged(_ sender: NSPopUpButton) {
        let selectedIndex = max(0, sender.indexOfSelectedItem)
        guard UpdateCheckStrategy.allCases.indices.contains(selectedIndex) else { return }
        settings.updateCheckStrategy = UpdateCheckStrategy.allCases[selectedIndex]
    }

    @objc private func changePane(_ sender: NSSegmentedControl) {
        guard let pane = PreferencesPane(rawValue: sender.selectedSegment) else { return }
        selectedPane = pane
        presentSelectedPane()
    }

    @objc private func languageChanged(_ sender: NSPopUpButton) {
        let selectedIndex = max(0, sender.indexOfSelectedItem)
        guard AppLanguage.allCases.indices.contains(selectedIndex) else { return }
        settings.appLanguage = AppLanguage.allCases[selectedIndex]
    }

    @objc private func appearanceChanged(_ sender: NSPopUpButton) {
        let selectedIndex = max(0, sender.indexOfSelectedItem)
        guard AppAppearance.allCases.indices.contains(selectedIndex) else { return }
        settings.appAppearance = AppAppearance.allCases[selectedIndex]
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

    var debugLanguagePopup: NSPopUpButton { languagePopup }
    var debugAppearancePopup: NSPopUpButton { appearancePopup }
    var debugCheckForUpdatesButtonTitle: String { checkNowButton.title }
    var debugOpenGitHubButtonTitle: String { openGitHubButton.title }
    var debugCardBackgroundColor: NSColor? { card.layer?.backgroundColor.flatMap(NSColor.init(cgColor:)) }
}

private func resolvedCGColor(_ color: NSColor, appearance: NSAppearance) -> CGColor {
    let previousAppearance = NSAppearance.current
    NSAppearance.current = appearance
    let resolvedColor = color.usingColorSpace(.deviceRGB)?.cgColor ?? color.cgColor
    NSAppearance.current = previousAppearance
    return resolvedColor
}

private final class AppearanceAwareView: NSView {
    var onEffectiveAppearanceChange: (() -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onEffectiveAppearanceChange?()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onEffectiveAppearanceChange?()
    }
}
