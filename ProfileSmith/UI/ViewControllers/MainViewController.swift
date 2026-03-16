import Cocoa
import Combine
import SnapKit

final class MainViewController: NSViewController {
    private let context: AppContext
    private let detailQueue = DispatchQueue(label: "cn.vanjay.ProfileSmith.detail", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    private var detailRequestID: UInt = 0
    private var searchDebounceWorkItem: DispatchWorkItem?
    private var selectedPaths: [String] = []
    private var currentProfiles: [ProfileRecord] = []
    private var currentParsedProfile: ParsedProfile?
    private var currentInspection: PreviewInspection?
    private var currentInspectorRoot: InspectorNode?
    private var previewWindowController: PreviewWindowController?

    private let filterPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let sortPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let searchField = NSSearchField(frame: .zero)
    private let refreshButton = NSButton(title: "刷新", target: nil, action: nil)
    private let importButton = NSButton(title: "导入/预览…", target: nil, action: nil)
    private let pluginButton = NSButton(title: "Finder Quick Look", target: nil, action: nil)
    private let progressIndicator = NSProgressIndicator()
    private let loadingOverlay = NSView()
    private let loadingPanel = NSVisualEffectView()
    private let loadingTitleLabel = NSTextField(labelWithString: "正在加载描述文件…")
    private let loadingHintLabel = NSTextField(labelWithString: "首次扫描或目录内容较多时会稍慢一些。")
    private let loadingPanelIndicator = NSProgressIndicator()

    private let splitView = NSSplitView()
    private let tableContainer = NSView()
    private let detailContainer = NSView()
    private let tableView = ProfilesTableView()
    private let tableScrollView = NSScrollView()
    private let titleLabel = NSTextField(labelWithString: "ProfileSmith")
    private let subtitleLabel = NSTextField(labelWithString: "选择一个描述文件查看详情")
    private let typeBadge = BadgeView()
    private let platformBadge = BadgeView()
    private let statusBadge = BadgeView()
    private let summaryTextView = NSTextView()
    private let summaryScrollView = NSScrollView()
    private let detailOutlineView = NSOutlineView()
    private let detailOutlineScrollView = NSScrollView()
    private let previewContentView = HTMLPreviewView()
    private let tabControl = NSSegmentedControl(labels: ["概要", "详情", "预览"], trackingMode: .selectOne, target: nil, action: nil)
    private let tabView = NSTabView()
    private let statusLabel = NSTextField(labelWithString: "准备就绪")
    private var preferredSplitPosition: CGFloat?
    private var isApplyingPreferredSplitPosition = false
    private var isRepositoryRefreshing = false

    private let minimumTablePaneWidth: CGFloat = 360
    private let minimumDetailPaneWidth: CGFloat = 540

    private lazy var actionButtons: [NSButton] = [
        makeActionButton(title: "预览", action: #selector(previewSelectedItems(_:))),
        makeActionButton(title: "Finder", action: #selector(showSelectedInFinder(_:))),
        makeActionButton(title: "导出", action: #selector(exportSelectedProfile(_:))),
        makeActionButton(title: "美化文件名", action: #selector(renameSelectedProfile(_:))),
        makeActionButton(title: "移到废纸篓", action: #selector(moveSelectedProfilesToTrash(_:))),
        makeActionButton(title: "彻底删除", action: #selector(deleteSelectedProfiles(_:))),
    ]

    private lazy var rootDropView: DropHostingView = {
        let view = DropHostingView()
        view.delegate = self
        return view
    }()

    private lazy var profileContextMenu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self
        return menu
    }()

    private lazy var detailContextMenu: NSMenu = {
        let menu = NSMenu()
        menu.delegate = self
        return menu
    }()

    init(context: AppContext) {
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = rootDropView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        bindRepository()
        configureInitialControls()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if ProcessInfo.processInfo.environment["PROFILESMITH_UI_TEST"] == "1" {
            view.window?.makeFirstResponder(searchField)
        }
        syncRepositoryRefreshState(snapshot: context.repository.snapshot)
        stabilizeSplitViewLayout()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        stabilizeSplitViewLayout()
    }

    func handleExternalFiles(_ urls: [URL]) {
        handleIncomingFiles(urls)
    }

    func presentImportPanel(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["mobileprovision", "provisionprofile", "ipa", "xcarchive", "appex", "app"]
        guard panel.runModal() == .OK else { return }
        handleIncomingFiles(panel.urls)
    }

    func presentQuickLookPluginPanel(_ sender: Any?) {
        let alert = NSAlert()
        let manager = context.quickLookPluginManager
        alert.messageText = manager.stateDescription
        alert.informativeText = manager.isAvailable
            ? "ProfileSmith 已内建 Finder Quick Look 扩展。点击“\(manager.buttonTitle)”后，Finder 就可以对 `.ipa`、`.xcarchive`、`.app`、`.appex`、`.mobileprovision` 和 `.provisionprofile` 文件按空格快速预览。"
            : "当前构建中未找到 Finder Quick Look 扩展，请先重新构建应用。"
        alert.addButton(withTitle: manager.buttonTitle)
        alert.addButton(withTitle: "取消")
        if alert.runModal() != .alertFirstButtonReturn { return }

        do {
            try manager.refreshRegistration()
            updatePluginButtonTitle()
        } catch {
            NSApp.presentError(error)
        }
    }

    private func buildUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let topBar = NSVisualEffectView()
        topBar.material = .headerView
        topBar.blendingMode = .withinWindow
        topBar.state = .active

        let topRow = NSStackView()
        topRow.orientation = .horizontal
        topRow.alignment = .centerY
        topRow.spacing = 10

        searchField.placeholderString = "全文搜索描述文件内容、Bundle ID、Team、UUID…"
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = self
        searchField.setAccessibilityIdentifier("main.searchField")

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        progressIndicator.isHidden = true
        progressIndicator.setAccessibilityIdentifier("main.progressIndicator")

        loadingOverlay.wantsLayer = true
        loadingOverlay.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.72).cgColor
        loadingOverlay.isHidden = true
        loadingOverlay.setAccessibilityIdentifier("main.loadingOverlay")

        loadingPanel.material = .hudWindow
        loadingPanel.blendingMode = .withinWindow
        loadingPanel.state = .active
        loadingPanel.wantsLayer = true
        loadingPanel.layer?.cornerRadius = 16

        loadingPanelIndicator.style = .spinning
        loadingPanelIndicator.controlSize = .regular
        loadingPanelIndicator.isDisplayedWhenStopped = false

        loadingTitleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        loadingHintLabel.font = .systemFont(ofSize: 12)
        loadingHintLabel.textColor = .secondaryLabelColor

        refreshButton.target = self
        refreshButton.action = #selector(refreshProfiles(_:))
        refreshButton.setAccessibilityIdentifier("main.refreshButton")
        importButton.target = self
        importButton.action = #selector(importOrPreview(_:))
        importButton.setAccessibilityIdentifier("main.importButton")
        pluginButton.target = self
        pluginButton.action = #selector(openQuickLookPluginPanel(_:))
        pluginButton.setAccessibilityIdentifier("main.quickLookButton")
        filterPopUp.setAccessibilityIdentifier("main.filterPopUp")
        sortPopUp.setAccessibilityIdentifier("main.sortPopUp")

        topRow.addArrangedSubview(filterPopUp)
        topRow.addArrangedSubview(sortPopUp)
        topRow.addArrangedSubview(searchField)
        topRow.addArrangedSubview(refreshButton)
        topRow.addArrangedSubview(importButton)
        topRow.addArrangedSubview(pluginButton)
        topRow.addArrangedSubview(progressIndicator)

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.autosaveName = "ProfileSmith.SplitView"
        splitView.setAccessibilityIdentifier("main.splitView")

        buildTableArea()
        buildDetailArea()

        tableContainer.addSubview(tableScrollView)
        tableContainer.setAccessibilityIdentifier("main.tablePane")
        tableContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tableContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tableScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        buildDetailContainer()
        detailContainer.setAccessibilityIdentifier("main.detailPane")
        detailContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        detailContainer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        splitView.addArrangedSubview(tableContainer)
        splitView.addArrangedSubview(detailContainer)

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setAccessibilityElement(true)
        statusLabel.setAccessibilityIdentifier("main.statusLabel")

        view.addSubview(topBar)
        topBar.addSubview(topRow)
        view.addSubview(splitView)
        view.addSubview(loadingOverlay)
        view.addSubview(statusLabel)

        loadingOverlay.addSubview(loadingPanel)
        loadingPanel.addSubview(loadingPanelIndicator)
        loadingPanel.addSubview(loadingTitleLabel)
        loadingPanel.addSubview(loadingHintLabel)

        topBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        topRow.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(14)
        }

        searchField.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(340)
        }

        splitView.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(statusLabel.snp.top).offset(-8)
        }

        loadingOverlay.snp.makeConstraints { make in
            make.edges.equalTo(splitView)
        }

        loadingPanel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(320)
        }

        loadingPanelIndicator.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.centerX.equalToSuperview()
        }

        loadingTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(loadingPanelIndicator.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        loadingHintLabel.snp.makeConstraints { make in
            make.top.equalTo(loadingTitleLabel.snp.bottom).offset(6)
            make.leading.trailing.bottom.equalToSuperview().inset(20)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-10)
        }
    }

    private func buildTableArea() {
        tableScrollView.hasVerticalScroller = true
        tableScrollView.borderType = .bezelBorder

        tableView.headerView = NSTableHeaderView()
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .sourceList
        tableView.rowHeight = 32
        tableView.allowsMultipleSelection = true
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        tableView.setAccessibilityIdentifier("main.profilesTable")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(previewSelectedItems(_:))
        tableView.quickLookHandler = { [weak self] in
            self?.previewSelectedItems(nil)
        }
        tableView.copyHandler = { [weak self] in
            self?.copySelectedRowContents(nil)
        }
        tableView.menu = profileContextMenu

        let columns: [(String, String, CGFloat)] = [
            ("name", "名称", 220),
            ("bundle", "Bundle ID", 210),
            ("team", "Team", 160),
            ("type", "类型", 150),
            ("expires", "到期", 120),
            ("status", "状态", 120),
        ]

        for (identifier, title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            column.minWidth = 90
            column.resizingMask = .userResizingMask
            tableView.addTableColumn(column)
        }

        tableView.tableColumns[0].sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)
        tableView.tableColumns[1].sortDescriptorPrototype = NSSortDescriptor(key: "bundleIdentifier", ascending: true)
        tableView.tableColumns[2].sortDescriptorPrototype = NSSortDescriptor(key: "teamName", ascending: true)
        tableView.tableColumns[4].sortDescriptorPrototype = NSSortDescriptor(key: "expirationDate", ascending: true)
        tableView.tableColumns[5].sortDescriptorPrototype = NSSortDescriptor(key: "status", ascending: true)

        tableScrollView.documentView = tableView
    }

    private func buildDetailArea() {
        titleLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 30) ?? .systemFont(ofSize: 30, weight: .semibold)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setAccessibilityElement(true)
        titleLabel.setAccessibilityIdentifier("main.titleLabel")
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingMiddle
        subtitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitleLabel.setAccessibilityElement(true)
        subtitleLabel.setAccessibilityIdentifier("main.subtitleLabel")

        tabControl.selectedSegment = 0
        tabControl.target = self
        tabControl.action = #selector(tabChanged(_:))
        tabControl.setAccessibilityIdentifier("main.tabControl")

        summaryTextView.isEditable = false
        summaryTextView.isSelectable = true
        summaryTextView.drawsBackground = false
        summaryTextView.font = .systemFont(ofSize: 13)
        summaryTextView.textColor = .labelColor
        summaryTextView.textContainerInset = NSSize(width: 6, height: 10)
        summaryTextView.setAccessibilityIdentifier("main.summaryTextView")
        summaryScrollView.hasVerticalScroller = true
        summaryScrollView.borderType = .bezelBorder
        summaryScrollView.documentView = summaryTextView

        detailOutlineView.delegate = self
        detailOutlineView.dataSource = self
        detailOutlineView.rowHeight = 28
        detailOutlineView.usesAlternatingRowBackgroundColors = false
        detailOutlineView.menu = detailContextMenu
        detailOutlineView.setAccessibilityIdentifier("main.detailOutlineView")
        let keyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("key"))
        keyColumn.title = "键"
        keyColumn.width = 200
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "类型"
        typeColumn.width = 110
        let detailColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("detail"))
        detailColumn.title = "值"
        detailColumn.width = 360
        detailOutlineView.addTableColumn(keyColumn)
        detailOutlineView.addTableColumn(typeColumn)
        detailOutlineView.addTableColumn(detailColumn)
        detailOutlineView.outlineTableColumn = keyColumn
        detailOutlineScrollView.hasVerticalScroller = true
        detailOutlineScrollView.borderType = .bezelBorder
        detailOutlineScrollView.documentView = detailOutlineView

        let overviewItem = NSTabViewItem(identifier: "overview")
        overviewItem.view = summaryScrollView
        let detailItem = NSTabViewItem(identifier: "detail")
        detailItem.view = detailOutlineScrollView
        let previewItem = NSTabViewItem(identifier: "preview")
        previewContentView.setAccessibilityIdentifier("main.previewView")
        previewItem.view = previewContentView

        tabView.tabViewType = .noTabsNoBorder
        tabView.addTabViewItem(overviewItem)
        tabView.addTabViewItem(detailItem)
        tabView.addTabViewItem(previewItem)
    }

    private func buildDetailContainer() {
        let badgesRow = NSStackView(views: [typeBadge, platformBadge, statusBadge])
        badgesRow.orientation = .horizontal
        badgesRow.alignment = .centerY
        badgesRow.spacing = 8
        badgesRow.edgeInsets = NSEdgeInsets()
        badgesRow.setHuggingPriority(.required, for: .vertical)

        let actionsRow = NSStackView(views: actionButtons)
        actionsRow.orientation = .horizontal
        actionsRow.alignment = .centerY
        actionsRow.spacing = 8
        actionsRow.distribution = .fillProportionally

        detailContainer.addSubview(titleLabel)
        detailContainer.addSubview(subtitleLabel)
        detailContainer.addSubview(badgesRow)
        detailContainer.addSubview(actionsRow)
        detailContainer.addSubview(tabControl)
        detailContainer.addSubview(tabView)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.leading.trailing.equalToSuperview().inset(18)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.leading.trailing.equalTo(titleLabel)
        }

        badgesRow.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(12)
            make.leading.equalTo(titleLabel)
        }

        actionsRow.snp.makeConstraints { make in
            make.top.equalTo(badgesRow.snp.bottom).offset(12)
            make.leading.trailing.equalTo(titleLabel)
        }

        tabControl.snp.makeConstraints { make in
            make.top.equalTo(actionsRow.snp.bottom).offset(14)
            make.leading.equalTo(titleLabel)
        }

        tabView.snp.makeConstraints { make in
            make.top.equalTo(tabControl.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(18)
        }
    }

    private func configureInitialControls() {
        filterPopUp.removeAllItems()
        ProfileFilter.allCases.forEach { filter in
            filterPopUp.addItem(withTitle: filter.title)
        }
        filterPopUp.target = self
        filterPopUp.action = #selector(filterChanged(_:))
        filterPopUp.selectItem(at: ProfileFilter.allCases.firstIndex(of: .all) ?? 0)

        sortPopUp.removeAllItems()
        ProfileSort.allCases.forEach { sort in
            sortPopUp.addItem(withTitle: sort.title)
        }
        sortPopUp.target = self
        sortPopUp.action = #selector(sortChanged(_:))
        sortPopUp.selectItem(at: ProfileSort.allCases.firstIndex(of: .expirationAscending) ?? 0)

        updatePluginButtonTitle()
        updateActionState()
        applyEmptyDetailState()
    }

    private func bindRepository() {
        context.repository.$snapshot
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshot in
                self?.applySnapshot(snapshot)
            }
            .store(in: &cancellables)

        context.repository.$isRefreshing
            .receive(on: RunLoop.main)
            .sink { [weak self] isRefreshing in
                guard let self else { return }
                self.applyRepositoryRefreshState(isRefreshing, snapshot: self.context.repository.snapshot)
            }
            .store(in: &cancellables)

        syncRepositoryRefreshState(snapshot: context.repository.snapshot)
    }

    private func applySnapshot(_ snapshot: RepositorySnapshot) {
        currentProfiles = snapshot.profiles
        let preservedPaths = selectedPaths
        tableView.reloadData()
        restoreSelection(for: preservedPaths)
        if currentProfiles.isEmpty {
            applyEmptyDetailState()
        } else if tableView.selectedRowIndexes.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        } else {
            reloadSelectionDrivenUI()
        }
        syncRepositoryRefreshState(snapshot: snapshot)
        stabilizeSplitViewLayout()
    }

    private func restoreSelection(for paths: [String]) {
        guard !paths.isEmpty else { return }
        let indexes = IndexSet(paths.compactMap { path in currentProfiles.firstIndex(where: { $0.path == path }) })
        guard !indexes.isEmpty else { return }
        tableView.selectRowIndexes(indexes, byExtendingSelection: false)
    }

    private func reloadSelectionDrivenUI() {
        let records = selectedRecords()
        selectedPaths = records.map(\.path)
        updateActionState()

        if records.isEmpty {
            applyEmptyDetailState()
            return
        }
        if records.count > 1 {
            applyBulkSelectionDetailState(records)
            return
        }

        loadDetails(for: records[0])
    }

    private func loadDetails(for record: ProfileRecord) {
        detailRequestID &+= 1
        let requestID = detailRequestID
        prepareDetailLoadingState(for: record)

        detailQueue.async { [weak self] in
            guard let self else { return }

            do {
                let parsedProfile = try self.context.repository.loadProfileDetails(for: record)
                let inspection = self.context.archiveInspector.makeInspection(for: parsedProfile, sourceURL: URL(fileURLWithPath: record.path))
                let rootNode = InspectorNodeBuilder.makeRootNode(from: parsedProfile.plist, certificates: parsedProfile.certificates)

                DispatchQueue.main.async {
                    guard self.detailRequestID == requestID else { return }
                    self.applyLoadedDetails(parsedProfile, inspection: inspection, rootNode: rootNode)
                }
            } catch {
                DispatchQueue.main.async {
                    guard self.detailRequestID == requestID else { return }
                    self.applyDetailLoadingError(error)
                }
            }
        }
    }

    private func prepareDetailLoadingState(for record: ProfileRecord) {
        currentParsedProfile = nil
        currentInspection = nil
        currentInspectorRoot = nil

        titleLabel.stringValue = record.displayName
        subtitleLabel.stringValue = record.path
        summaryTextView.string = "正在解析描述文件详情…"
        previewContentView.loadHTMLString(
            makePreviewStatusHTML(title: "正在生成预览", message: "请稍候，ProfileSmith 正在整理描述文件和签名信息。"),
            baseURL: nil
        )
        typeBadge.configure(text: record.profileType, fillColor: NSColor.systemBlue.withAlphaComponent(0.16), textColor: .systemBlue)
        platformBadge.configure(text: record.profilePlatform, fillColor: NSColor.quaternaryLabelColor.withAlphaComponent(0.15), textColor: .secondaryLabelColor)
        statusBadge.configure(text: record.statusText, fillColor: badgeColor(for: record).withAlphaComponent(0.16), textColor: badgeColor(for: record))
        stabilizeSplitViewLayout()
    }

    private func applyLoadedDetails(_ parsedProfile: ParsedProfile, inspection: PreviewInspection, rootNode: InspectorNode) {
        currentParsedProfile = parsedProfile
        currentInspection = inspection
        currentInspectorRoot = rootNode
        detailOutlineView.reloadData()
        detailOutlineView.expandItem(nil, expandChildren: true)
        previewContentView.loadHTMLString(inspection.quickLookHTML, baseURL: nil)
        summaryTextView.string = makeSummaryText(for: parsedProfile)
        titleLabel.stringValue = parsedProfile.record.displayName
        subtitleLabel.stringValue = parsedProfile.record.path
        stabilizeSplitViewLayout()
    }

    private func applyDetailLoadingError(_ error: Error) {
        currentParsedProfile = nil
        currentInspection = nil
        currentInspectorRoot = nil
        detailOutlineView.reloadData()
        summaryTextView.string = "解析失败：\(error.localizedDescription)"
        previewContentView.loadHTMLString(
            makePreviewStatusHTML(title: "预览生成失败", message: error.localizedDescription),
            baseURL: nil
        )
        stabilizeSplitViewLayout()
    }

    private func applyEmptyDetailState() {
        titleLabel.stringValue = "ProfileSmith"
        subtitleLabel.stringValue = "拖入描述文件、IPA、XCArchive 或 APPEX，或在左侧选择已有描述文件。"
        typeBadge.configure(text: nil, fillColor: .clear)
        platformBadge.configure(text: nil, fillColor: .clear)
        statusBadge.configure(text: nil, fillColor: .clear)
        summaryTextView.string = """
        使用说明

        1. 左侧列表展示 `~/Library/MobileDevice/Provisioning Profiles` 和 `~/Library/Developer/Xcode/UserData/Provisioning Profiles` 中的描述文件。
        2. 支持全文搜索、批量选中、Finder 定位、导出、移到废纸篓、彻底删除和文件名美化。
        3. 可以直接拖入 `.mobileprovision` / `.provisionprofile` 安装，也可以拖入 `.ipa` / `.xcarchive` / `.appex` / `.app` 做描述文件与 Info.plist 预览。
        4. Finder Quick Look 已随应用内建；若 Finder 尚未识别，可点击顶部 `Finder Quick Look` 按钮刷新注册。
        """
        previewContentView.loadHTMLString(
            makePreviewStatusHTML(title: "ProfileSmith", message: "选择一个描述文件，或直接把文件拖进窗口。"),
            baseURL: nil
        )
        currentInspectorRoot = nil
        detailOutlineView.reloadData()
        updateActionState()
        stabilizeSplitViewLayout()
    }

    private func applyBulkSelectionDetailState(_ records: [ProfileRecord]) {
        let expiredCount = records.filter(\.isExpired).count
        let uniqueTeams = Set(records.compactMap(\.teamName)).count

        titleLabel.stringValue = "\(records.count) 个描述文件"
        subtitleLabel.stringValue = "已选择多个项目，可以批量在 Finder 中显示、移到废纸篓或彻底删除。"
        typeBadge.configure(text: "批量操作", fillColor: NSColor.systemBlue.withAlphaComponent(0.16), textColor: .systemBlue)
        platformBadge.configure(text: "\(uniqueTeams) 个 Team", fillColor: NSColor.systemGray.withAlphaComponent(0.14), textColor: .secondaryLabelColor)
        statusBadge.configure(text: "已过期 \(expiredCount) 个", fillColor: NSColor.systemOrange.withAlphaComponent(0.16), textColor: .systemOrange)
        summaryTextView.string = records.map { record in
            "\(record.displayName)\n  \(record.bundleIdentifier ?? record.appIDName ?? "-")\n  \(record.profileType ?? "-") | \(record.statusText)\n  \(record.path)"
        }.joined(separator: "\n\n")
        previewContentView.loadHTMLString(
            makePreviewStatusHTML(title: "已选择 \(records.count) 个描述文件", message: "批量操作可用，详情树和预览仅在单选时展示。"),
            baseURL: nil
        )
        currentParsedProfile = nil
        currentInspection = nil
        currentInspectorRoot = nil
        detailOutlineView.reloadData()
        stabilizeSplitViewLayout()
    }

    private func makePreviewStatusHTML(title: String, message: String) -> String {
        let escapedTitle = escapePreviewHTML(title)
        let escapedMessage = escapePreviewHTML(message).replacingOccurrences(of: "\n", with: "<br>")
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="color-scheme" content="light dark">
        <style>
        :root {
            color-scheme: light dark;
            --ink:#152132;
            --muted:#5d7084;
            --line:rgba(21,33,50,0.10);
            --card:rgba(255,255,255,0.92);
            --accent:#1e6fd9;
            --tint:rgba(30,111,217,0.12);
            --shadow:0 16px 36px rgba(36,54,84,0.10);
            --bg-top:#f5f8fc;
            --bg-bottom:#e9eff6;
        }
        @media (prefers-color-scheme: dark) {
            :root {
                --ink:#e8eef7;
                --muted:#9badc2;
                --line:rgba(194,208,228,0.14);
                --card:rgba(18,25,35,0.94);
                --accent:#7cb2ff;
                --tint:rgba(124,178,255,0.16);
                --shadow:0 18px 40px rgba(0,0,0,0.34);
                --bg-top:#121923;
                --bg-bottom:#0b1017;
            }
        }
        * { box-sizing: border-box; }
        html { background: var(--bg-bottom); }
        body {
            margin: 0;
            padding: 18px;
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
            color: var(--ink);
            background:
                radial-gradient(circle at top left, rgba(98,146,220,0.18), transparent 30%),
                linear-gradient(180deg, var(--bg-top), var(--bg-bottom));
        }
        .card {
            max-width: 920px;
            margin: 0 auto;
            padding: 22px 24px;
            border: 1px solid var(--line);
            border-radius: 18px;
            background: var(--card);
            box-shadow: var(--shadow);
        }
        .badge {
            display:inline-flex;
            align-items:center;
            margin-bottom:12px;
            padding:8px 12px;
            border-radius:999px;
            background:var(--tint);
            color:var(--accent);
            font-size:12px;
            font-weight:700;
            letter-spacing:0.08em;
            text-transform:uppercase;
        }
        h1 {
            margin: 0 0 8px;
            font-size: 24px;
            line-height: 1.2;
        }
        p {
            margin: 0;
            color: var(--muted);
            font-size: 14px;
            line-height: 1.6;
        }
        </style>
        </head>
        <body>
            <section class="card">
                <div class="badge">Preview</div>
                <h1>\(escapedTitle)</h1>
                <p>\(escapedMessage)</p>
            </section>
        </body>
        </html>
        """
    }

    private func escapePreviewHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func makeSummaryText(for parsedProfile: ParsedProfile) -> String {
        let record = parsedProfile.record
        let entitlements = parsedProfile.plist["Entitlements"] as? [String: Any] ?? [:]
        let entitlementsText = entitlements.keys.sorted().map { key in
            "\(key): \(String(describing: entitlements[key] ?? ""))"
        }.joined(separator: "\n")
        let certificateText = parsedProfile.certificates.map { certificate in
            var parts = ["\(certificate.summary)"]
            if let organization = certificate.organization {
                parts.append("组织: \(organization)")
            }
            if let invalidityDate = certificate.invalidityDate {
                parts.append("失效时间: \(Formatters.timestampString(from: invalidityDate))")
            }
            parts.append("SHA1: \(certificate.sha1)")
            parts.append("SHA256: \(certificate.sha256)")
            return parts.joined(separator: "\n")
        }.joined(separator: "\n\n")

        return """
        基本信息
        名称: \(record.displayName)
        UUID: \(record.uuid ?? "-")
        Bundle ID: \(record.bundleIdentifier ?? "-")
        App ID Name: \(record.appIDName ?? "-")
        Application Identifier: \(record.applicationIdentifier ?? "-")
        Team: \(record.teamName ?? "-")
        Team Identifier: \(record.teamIdentifier ?? "-")
        平台: \(record.profilePlatform ?? "-")
        类型: \(record.profileType ?? "-")
        创建时间: \(record.creationDateValue.map(Formatters.timestampString(from:)) ?? "-")
        到期时间: \(record.expirationDateValue.map(Formatters.timestampString(from:)) ?? "-")
        剩余天数: \(record.daysUntilExpiration.map(String.init) ?? "-")
        设备数量: \(record.deviceCount)
        证书数量: \(record.certificateCount)
        来源目录: \(record.sourceName)
        文件路径: \(record.path)

        Entitlements
        \(entitlementsText.isEmpty ? "-" : entitlementsText)

        证书
        \(certificateText.isEmpty ? "-" : certificateText)
        """
    }

    private func updateActionState() {
        let selectionCount = selectedRecords().count
        actionButtons.enumerated().forEach { index, button in
            switch index {
            case 0, 1, 4, 5:
                button.isEnabled = selectionCount > 0
            default:
                button.isEnabled = selectionCount == 1
            }
        }
        tabControl.isEnabled = selectionCount == 1
    }

    private func updateStatusLabel(snapshot: RepositorySnapshot) {
        let selectionCount = selectedRecords().count
        let currentResultCount = snapshot.profiles.count
        let totalCount = snapshot.metrics.totalCount
        let expiredCount = snapshot.metrics.expiredCount
        let expiringSoonCount = snapshot.metrics.expiringSoonCount
        let refreshText = snapshot.lastRefreshDate.map { "最近刷新 \(Formatters.timestampString(from: $0))" } ?? "尚未刷新"
        let prefix = isRepositoryRefreshing ? "正在加载… " : ""

        if selectionCount > 0 {
            statusLabel.stringValue = "\(prefix)当前结果 \(currentResultCount) 条，已选中 \(selectionCount) 条，总计 \(totalCount) 条，过期 \(expiredCount) 条，30 天内到期 \(expiringSoonCount) 条。\(refreshText)"
        } else {
            statusLabel.stringValue = "\(prefix)当前结果 \(currentResultCount) 条，总计 \(totalCount) 条，过期 \(expiredCount) 条，30 天内到期 \(expiringSoonCount) 条。\(refreshText)"
        }
    }

    private func updateLoadingOverlay() {
        let shouldShow = isRepositoryRefreshing && currentProfiles.isEmpty
        loadingOverlay.isHidden = !shouldShow
        if shouldShow {
            loadingPanelIndicator.startAnimation(nil)
        } else {
            loadingPanelIndicator.stopAnimation(nil)
        }
    }

    private func applyRepositoryRefreshState(_ isRefreshing: Bool, snapshot: RepositorySnapshot? = nil) {
        isRepositoryRefreshing = isRefreshing
        progressIndicator.isHidden = !isRefreshing
        if isRefreshing {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
        updateLoadingOverlay()
        if let snapshot {
            updateStatusLabel(snapshot: snapshot)
        }
    }

    private func syncRepositoryRefreshState(snapshot: RepositorySnapshot? = nil) {
        applyRepositoryRefreshState(context.repository.isRefreshing, snapshot: snapshot ?? context.repository.snapshot)
    }

    private func stabilizeSplitViewLayout() {
        guard splitView.arrangedSubviews.count == 2 else { return }

        if preferredSplitPosition == nil {
            let currentWidth = tableContainer.frame.width
            if currentWidth > 0 {
                preferredSplitPosition = currentWidth
            }
        }

        guard let preferredSplitPosition else { return }
        let clampedPosition = clampedSplitPosition(for: preferredSplitPosition)
        let currentPosition = tableContainer.frame.width
        guard abs(currentPosition - clampedPosition) > 0.5 else { return }

        isApplyingPreferredSplitPosition = true
        splitView.setPosition(clampedPosition, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()
        isApplyingPreferredSplitPosition = false
    }

    private func clampedSplitPosition(for proposedPosition: CGFloat) -> CGFloat {
        let availableWidth = max(0, splitView.bounds.width - splitView.dividerThickness)
        guard availableWidth > 0 else { return proposedPosition }

        let minimumCombinedWidth = minimumTablePaneWidth + minimumDetailPaneWidth
        if availableWidth <= minimumCombinedWidth {
            return round(availableWidth * 0.42)
        }

        let maximumTableWidth = availableWidth - minimumDetailPaneWidth
        return min(max(proposedPosition, minimumTablePaneWidth), maximumTableWidth)
    }

    private var isUserDraggingSplitDivider: Bool {
        guard NSEvent.pressedMouseButtons != 0 else { return false }
        guard let event = NSApp.currentEvent else { return false }
        switch event.type {
        case .leftMouseDown, .leftMouseDragged, .otherMouseDown, .otherMouseDragged:
            return true
        default:
            return false
        }
    }

    private func selectedRecords() -> [ProfileRecord] {
        let indexes = tableView.selectedRowIndexes
        guard !indexes.isEmpty else { return [] }
        return indexes.compactMap { index in
            guard currentProfiles.indices.contains(index) else { return nil }
            return currentProfiles[index]
        }
    }

    private func effectiveProfileContextSelection() -> [ProfileRecord] {
        let selected = selectedRecords()
        if !selected.isEmpty {
            return selected
        }
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0, currentProfiles.indices.contains(clickedRow) else { return [] }
        return [currentProfiles[clickedRow]]
    }

    private func effectiveInspectorNode() -> InspectorNode? {
        if let item = detailOutlineView.item(atRow: detailOutlineView.clickedRow) as? InspectorNode {
            return item
        }
        if let item = detailOutlineView.item(atRow: detailOutlineView.selectedRow) as? InspectorNode {
            return item
        }
        return nil
    }

    private func badgeColor(for record: ProfileRecord) -> NSColor {
        if record.isExpired {
            return .systemRed
        }
        if let days = record.daysUntilExpiration, days <= 30 {
            return .systemOrange
        }
        return .systemGreen
    }

    private func optimisticRenamedRecord(from record: ProfileRecord, renamedURL: URL) -> ProfileRecord {
        var renamedRecord = record
        renamedRecord.path = renamedURL.path
        renamedRecord.fileName = renamedURL.deletingPathExtension().lastPathComponent
        return renamedRecord
    }

    private func makeActionButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 12, weight: .medium)
        return button
    }

    private func updatePluginButtonTitle() {
        let manager = context.quickLookPluginManager
        pluginButton.title = manager.buttonTitle
        pluginButton.isEnabled = manager.isAvailable
    }

    private func sanitizeFileName(_ input: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = input
            .components(separatedBy: invalidCharacters)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Profile" : cleaned
    }

    private func handleIncomingFiles(_ urls: [URL]) {
        let profileURLs = urls.filter(ProfileScanner.isSupportedProfileFile(url:))
        let previewURLs = urls.filter { !ProfileScanner.isSupportedProfileFile(url: $0) }

        do {
            if !profileURLs.isEmpty {
                let result = try context.fileOperations.importProfiles(from: profileURLs)
                context.repository.refresh(forceReindex: false)

                if !result.installedURLs.isEmpty || !result.skippedURLs.isEmpty {
                    let alert = NSAlert()
                    alert.messageText = "导入完成"
                    alert.informativeText = "已安装 \(result.installedURLs.count) 个，已跳过 \(result.skippedURLs.count) 个重复文件。"
                    alert.runModal()
                }
            }

            if let previewURL = previewURLs.first {
                let inspection = try context.repository.inspectArchive(at: previewURL)
                showPreviewWindow(for: inspection)
            }
        } catch {
            NSApp.presentError(error)
        }
    }

    private func showPreviewWindow(for inspection: PreviewInspection) {
        let windowController = PreviewWindowController(inspection: inspection)
        previewWindowController = windowController
        windowController.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func refreshProfiles(_ sender: Any?) {
        context.repository.refresh(forceReindex: false)
    }

    @objc private func importOrPreview(_ sender: Any?) {
        presentImportPanel(sender)
    }

    @objc private func openQuickLookPluginPanel(_ sender: Any?) {
        presentQuickLookPluginPanel(sender)
    }

    @objc private func filterChanged(_ sender: Any?) {
        let index = max(0, filterPopUp.indexOfSelectedItem)
        context.repository.setFilter(ProfileFilter.allCases[index])
    }

    @objc private func sortChanged(_ sender: Any?) {
        let index = max(0, sortPopUp.indexOfSelectedItem)
        context.repository.setSort(ProfileSort.allCases[index])
    }

    @objc private func tabChanged(_ sender: Any?) {
        tabView.selectTabViewItem(at: tabControl.selectedSegment)
    }

    @objc private func previewSelectedItems(_ sender: Any?) {
        let records = selectedRecords()
        guard records.count == 1 else { return }
        do {
            let inspection = try context.repository.inspectArchive(at: URL(fileURLWithPath: records[0].path))
            showPreviewWindow(for: inspection)
        } catch {
            NSApp.presentError(error)
        }
    }

    @objc private func showSelectedInFinder(_ sender: Any?) {
        let urls = effectiveProfileContextSelection().map { URL(fileURLWithPath: $0.path) }
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    @objc private func exportSelectedProfile(_ sender: Any?) {
        guard let record = selectedRecords().first else { return }

        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = sanitizeFileName(record.displayName)
        savePanel.allowedFileTypes = [record.fileExtension]
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else { return }

        do {
            try context.fileOperations.exportProfile(from: URL(fileURLWithPath: record.path), to: destinationURL)
        } catch {
            NSApp.presentError(error)
        }
    }

    @objc private func renameSelectedProfile(_ sender: Any?) {
        guard let record = selectedRecords().first else { return }
        do {
            let renamedURL = try context.fileOperations.beautifyFilename(for: record)
            selectedPaths = [renamedURL.path]
            detailRequestID &+= 1
            prepareDetailLoadingState(for: optimisticRenamedRecord(from: record, renamedURL: renamedURL))
            summaryTextView.string = "已完成文件名美化，正在刷新索引与详情…"
            context.repository.refresh(forceReindex: false)
        } catch {
            NSApp.presentError(error)
        }
    }

    @objc private func moveSelectedProfilesToTrash(_ sender: Any?) {
        handleProfileDeletion(permanently: false)
    }

    @objc private func deleteSelectedProfiles(_ sender: Any?) {
        handleProfileDeletion(permanently: true)
    }

    private func handleProfileDeletion(permanently: Bool) {
        let records = effectiveProfileContextSelection()
        guard !records.isEmpty else { return }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = permanently ? "彻底删除所选描述文件？" : "将所选描述文件移到废纸篓？"
        let previewNames = records.prefix(10).map(\.displayName).joined(separator: "\n")
        let suffix = records.count > 10 ? "\n…" : ""
        alert.informativeText = "\(previewNames)\(suffix)"
        alert.addButton(withTitle: permanently ? "删除" : "移到废纸篓")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            try context.fileOperations.deleteProfiles(at: records.map { URL(fileURLWithPath: $0.path) }, permanently: permanently)
            selectedPaths = []
            context.repository.refresh(forceReindex: false)
        } catch {
            NSApp.presentError(error)
        }
    }

    @objc private func copySelectedPaths(_ sender: Any?) {
        let records = effectiveProfileContextSelection()
        guard !records.isEmpty else { return }
        copyTextToPasteboard(records.map(\.path).joined(separator: "\n"))
    }

    @objc private func copySelectedRowContents(_ sender: Any?) {
        let records = effectiveProfileContextSelection()
        guard !records.isEmpty else { return }
        let content = records
            .map(tableRowClipboardString(for:))
            .joined(separator: "\n")
        copyTextToPasteboard(content)
    }

    @objc private func exportSelectedCertificate(_ sender: Any?) {
        guard let node = effectiveInspectorNode(),
              node.kind == .certificate,
              let data = node.rawValue as? Data
        else { return }

        let savePanel = NSSavePanel()
        let fileName = sanitizeFileName(node.certificateSummary?.summary ?? node.key)
        savePanel.nameFieldStringValue = fileName
        savePanel.allowedFileTypes = ["cer", "pem"]
        guard savePanel.runModal() == .OK, let destinationURL = savePanel.url else { return }

        let base64 = data.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        let pem = """
        -----BEGIN CERTIFICATE-----
        \(base64)
        -----END CERTIFICATE-----
        """

        do {
            try pem.write(to: destinationURL, atomically: true, encoding: .utf8)
        } catch {
            NSApp.presentError(error)
        }
    }

    @objc private func copyCertificateSHA1(_ sender: Any?) {
        guard let summary = effectiveInspectorNode()?.certificateSummary else { return }
        copyTextToPasteboard(summary.sha1)
    }

    @objc private func copyCertificateSHA256(_ sender: Any?) {
        guard let summary = effectiveInspectorNode()?.certificateSummary else { return }
        copyTextToPasteboard(summary.sha256)
    }

    private func tableRowClipboardString(for record: ProfileRecord) -> String {
        [
            record.displayName,
            record.bundleIdentifier ?? record.appIDName ?? "-",
            record.teamName ?? "-",
            record.profileType ?? "-",
            record.expirationDateValue.map(Formatters.dayString(from:)) ?? "-",
            record.statusText,
        ].joined(separator: "\t")
    }

    private func copyTextToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

extension MainViewController: DropHostingViewDelegate {
    func dropHostingView(_ view: DropHostingView, didReceiveFileURLs urls: [URL]) {
        handleIncomingFiles(urls)
    }
}

extension MainViewController: NSSplitViewDelegate {
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        minimumTablePaneWidth
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        max(minimumTablePaneWidth, splitView.bounds.width - splitView.dividerThickness - minimumDetailPaneWidth)
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard !isApplyingPreferredSplitPosition else { return }
        guard isUserDraggingSplitDivider else {
            stabilizeSplitViewLayout()
            return
        }
        preferredSplitPosition = tableContainer.frame.width
    }
}

extension MainViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        currentProfiles.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard currentProfiles.indices.contains(row),
              let tableColumn
        else { return nil }

        let record = currentProfiles[row]
        let identifier = NSUserInterfaceItemIdentifier("ProfileCell.\(tableColumn.identifier.rawValue)")
        let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView ?? {
            let cell = NSTableCellView()
            let textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingMiddle
            textField.maximumNumberOfLines = 1
            cell.addSubview(textField)
            textField.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(6)
                make.centerY.equalToSuperview()
            }
            cell.textField = textField
            cell.identifier = identifier
            return cell
        }()

        switch tableColumn.identifier.rawValue {
        case "name":
            cell.textField?.stringValue = record.displayName
            cell.textField?.font = .systemFont(ofSize: 13, weight: .semibold)
            cell.textField?.textColor = .labelColor
        case "bundle":
            cell.textField?.stringValue = record.bundleIdentifier ?? record.appIDName ?? "-"
            cell.textField?.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            cell.textField?.textColor = .secondaryLabelColor
        case "team":
            cell.textField?.stringValue = record.teamName ?? "-"
            cell.textField?.font = .systemFont(ofSize: 12)
            cell.textField?.textColor = .secondaryLabelColor
        case "type":
            cell.textField?.stringValue = record.profileType ?? "-"
            cell.textField?.font = .systemFont(ofSize: 12)
            cell.textField?.textColor = .secondaryLabelColor
        case "expires":
            cell.textField?.stringValue = record.expirationDateValue.map(Formatters.dayString(from:)) ?? "-"
            cell.textField?.font = .systemFont(ofSize: 12)
            cell.textField?.textColor = .secondaryLabelColor
        case "status":
            cell.textField?.stringValue = record.statusText
            cell.textField?.font = .systemFont(ofSize: 12, weight: .medium)
            cell.textField?.textColor = badgeColor(for: record)
        default:
            cell.textField?.stringValue = ""
        }

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        reloadSelectionDrivenUI()
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        guard let descriptor = tableView.sortDescriptors.first else { return }
        switch descriptor.key {
        case "name":
            sortPopUp.selectItem(at: ProfileSort.allCases.firstIndex(of: .nameAscending) ?? 0)
            context.repository.setSort(.nameAscending)
        case "teamName":
            sortPopUp.selectItem(at: ProfileSort.allCases.firstIndex(of: .teamAscending) ?? 0)
            context.repository.setSort(.teamAscending)
        case "expirationDate":
            let sort: ProfileSort = descriptor.ascending ? .expirationAscending : .expirationDescending
            sortPopUp.selectItem(at: ProfileSort.allCases.firstIndex(of: sort) ?? 0)
            context.repository.setSort(sort)
        default:
            break
        }
    }
}

extension MainViewController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        searchDebounceWorkItem?.cancel()
        let searchText = searchField.stringValue
        let workItem = DispatchWorkItem { [weak self] in
            self?.context.repository.setSearchText(searchText)
        }
        searchDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }
}

extension MainViewController: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let node = (item as? InspectorNode) ?? currentInspectorRoot
        return node?.children.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? InspectorNode else { return false }
        return !node.children.isEmpty
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let node = (item as? InspectorNode) ?? currentInspectorRoot
        return node!.children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? InspectorNode,
              let tableColumn
        else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("InspectorCell.\(tableColumn.identifier.rawValue)")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView ?? {
            let cell = NSTableCellView()
            let textField = NSTextField(labelWithString: "")
            textField.lineBreakMode = .byTruncatingMiddle
            textField.maximumNumberOfLines = 1
            cell.addSubview(textField)
            textField.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(4)
                make.centerY.equalToSuperview()
            }
            cell.textField = textField
            cell.identifier = identifier
            return cell
        }()

        switch tableColumn.identifier.rawValue {
        case "key":
            cell.textField?.stringValue = node.key
            cell.textField?.font = .systemFont(ofSize: 12, weight: .medium)
            cell.textField?.textColor = .labelColor
        case "type":
            cell.textField?.stringValue = node.type
            cell.textField?.font = .systemFont(ofSize: 11)
            cell.textField?.textColor = .secondaryLabelColor
        default:
            cell.textField?.stringValue = node.detail
            cell.textField?.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            cell.textField?.textColor = node.kind == .certificate ? .systemBlue : .secondaryLabelColor
        }

        return cell
    }
}

extension MainViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if menu === profileContextMenu {
            let selection = effectiveProfileContextSelection()
            guard !selection.isEmpty else { return }

            let previewItem = NSMenuItem(title: "快速预览", action: #selector(previewSelectedItems(_:)), keyEquivalent: "")
            previewItem.target = self
            previewItem.isEnabled = selection.count == 1
            menu.addItem(previewItem)

            let finderItem = NSMenuItem(title: "在 Finder 中显示", action: #selector(showSelectedInFinder(_:)), keyEquivalent: "")
            finderItem.target = self
            menu.addItem(finderItem)

            let copyPathItem = NSMenuItem(title: "复制路径", action: #selector(copySelectedPaths(_:)), keyEquivalent: "")
            copyPathItem.target = self
            menu.addItem(copyPathItem)

            let copyRowItem = NSMenuItem(title: "复制行内容", action: #selector(copySelectedRowContents(_:)), keyEquivalent: "")
            copyRowItem.target = self
            menu.addItem(copyRowItem)

            let exportItem = NSMenuItem(title: "导出描述文件…", action: #selector(exportSelectedProfile(_:)), keyEquivalent: "")
            exportItem.target = self
            exportItem.isEnabled = selection.count == 1
            menu.addItem(exportItem)

            let renameItem = NSMenuItem(title: "美化文件名", action: #selector(renameSelectedProfile(_:)), keyEquivalent: "")
            renameItem.target = self
            renameItem.isEnabled = selection.count == 1
            menu.addItem(renameItem)

            menu.addItem(NSMenuItem.separator())

            let trashItem = NSMenuItem(title: "移到废纸篓", action: #selector(moveSelectedProfilesToTrash(_:)), keyEquivalent: "")
            trashItem.target = self
            menu.addItem(trashItem)

            let deleteItem = NSMenuItem(title: "彻底删除", action: #selector(deleteSelectedProfiles(_:)), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)
            return
        }

        guard let node = effectiveInspectorNode(), node.kind == .certificate else { return }

        let exportItem = NSMenuItem(title: "导出证书文件…", action: #selector(exportSelectedCertificate(_:)), keyEquivalent: "")
        exportItem.target = self
        menu.addItem(exportItem)

        let copySHA1Item = NSMenuItem(title: "复制 SHA1", action: #selector(copyCertificateSHA1(_:)), keyEquivalent: "")
        copySHA1Item.target = self
        menu.addItem(copySHA1Item)

        let copySHA256Item = NSMenuItem(title: "复制 SHA256", action: #selector(copyCertificateSHA256(_:)), keyEquivalent: "")
        copySHA256Item.target = self
        menu.addItem(copySHA256Item)
    }
}

#if DEBUG
extension MainViewController {
    var debugTableView: ProfilesTableView { tableView }
    var debugSplitView: NSSplitView { splitView }
    var debugTitleLabel: NSTextField { titleLabel }
    var debugSubtitleLabel: NSTextField { subtitleLabel }
    var debugSummaryTextView: NSTextView { summaryTextView }
    var debugPreviewText: String { previewContentView.debugPlainText }
    var debugSearchField: NSSearchField { searchField }
    var debugStatusLabel: NSTextField { statusLabel }
    var debugProgressIndicator: NSProgressIndicator { progressIndicator }

    func debugApplySnapshot(_ snapshot: RepositorySnapshot) {
        applySnapshot(snapshot)
    }

    func debugApplyRepositoryRefreshState(_ isRefreshing: Bool) {
        applyRepositoryRefreshState(isRefreshing, snapshot: context.repository.snapshot)
    }

    func debugReloadSelectionDrivenUI() {
        reloadSelectionDrivenUI()
    }

    func debugLoadDetails(for record: ProfileRecord) {
        loadDetails(for: record)
    }

    func debugLoadDetailsSynchronously(for record: ProfileRecord) throws {
        detailRequestID &+= 1
        prepareDetailLoadingState(for: record)
        let parsedProfile = try context.repository.loadProfileDetails(for: record)
        let inspection = context.archiveInspector.makeInspection(for: parsedProfile, sourceURL: URL(fileURLWithPath: record.path))
        let rootNode = InspectorNodeBuilder.makeRootNode(from: parsedProfile.plist, certificates: parsedProfile.certificates)
        applyLoadedDetails(parsedProfile, inspection: inspection, rootNode: rootNode)
    }
}
#endif
