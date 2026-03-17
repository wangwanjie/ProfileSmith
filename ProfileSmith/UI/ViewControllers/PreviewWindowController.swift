import Cocoa
import SnapKit
import WebKit

private struct PreviewOverviewRow {
    let key: String
    let value: String
}

final class PreviewWindowController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate {
    private let inspection: PreviewInspection
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let segmentedControl = NSSegmentedControl(labels: ["总览", "描述文件", "Info.plist"], trackingMode: .selectOne, target: nil, action: nil)
    private let tabView = NSTabView()
    private let overviewTableView = CopyableTableView()
    private let overviewScrollView = NSScrollView()
    private let profileOutlineView = CopyableOutlineView()
    private let profileOutlineScrollView = NSScrollView()
    private let infoOutlineView = CopyableOutlineView()
    private let infoOutlineScrollView = NSScrollView()
    private let overviewContextMenu = NSMenu()
    private let profileContextMenu = NSMenu()
    private let infoContextMenu = NSMenu()
    private var overviewRows: [PreviewOverviewRow] = []
    private var profileRootNode: InspectorNode?
    private var infoRootNode: InspectorNode?

    init(inspection: PreviewInspection) {
        self.inspection = inspection

        let contentViewController = NSViewController()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = inspection.title
        window.center()
        window.contentViewController = contentViewController
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false

        super.init(window: window)

        buildUI(in: contentViewController.view)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI(in view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        titleLabel.font = NSFont(name: "Avenir Next Demi Bold", size: 28) ?? .systemFont(ofSize: 28, weight: .semibold)
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingMiddle

        segmentedControl.selectedSegment = 0
        segmentedControl.target = self
        segmentedControl.action = #selector(segmentChanged(_:))

        tabView.tabViewType = .noTabsNoBorder

        configureOverviewTableView()
        configureOutlineView(profileOutlineView)
        configureOutlineView(infoOutlineView)

        overviewTableView.copyHandler = { [weak self] in
            self?.copySelectedOverviewRows(nil)
        }
        profileOutlineView.copyHandler = { [weak self] in
            self?.copySelectedProfileRows(nil)
        }
        infoOutlineView.copyHandler = { [weak self] in
            self?.copySelectedInfoRows(nil)
        }

        overviewContextMenu.delegate = self
        profileContextMenu.delegate = self
        infoContextMenu.delegate = self
        overviewTableView.menu = overviewContextMenu
        profileOutlineView.menu = profileContextMenu
        infoOutlineView.menu = infoContextMenu

        overviewScrollView.documentView = overviewTableView
        overviewScrollView.hasVerticalScroller = true
        overviewScrollView.borderType = .bezelBorder

        profileOutlineScrollView.documentView = profileOutlineView
        profileOutlineScrollView.hasVerticalScroller = true
        profileOutlineScrollView.borderType = .bezelBorder

        infoOutlineScrollView.documentView = infoOutlineView
        infoOutlineScrollView.hasVerticalScroller = true
        infoOutlineScrollView.borderType = .bezelBorder

        let detailContainer = NSView()
        detailContainer.addSubview(profileOutlineScrollView)
        profileOutlineScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let infoContainer = NSView()
        infoContainer.addSubview(infoOutlineScrollView)
        infoOutlineScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let overviewTab = NSTabViewItem(identifier: "overview")
        overviewTab.view = overviewScrollView
        let profileTab = NSTabViewItem(identifier: "profile")
        profileTab.view = detailContainer
        let infoTab = NSTabViewItem(identifier: "info")
        infoTab.view = infoContainer
        tabView.addTabViewItem(overviewTab)
        tabView.addTabViewItem(profileTab)
        tabView.addTabViewItem(infoTab)

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(segmentedControl)
        view.addSubview(tabView)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
        }

        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-24)
        }

        segmentedControl.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(16)
            make.leading.equalTo(titleLabel)
        }

        tabView.snp.makeConstraints { make in
            make.top.equalTo(segmentedControl.snp.bottom).offset(16)
            make.leading.trailing.bottom.equalToSuperview().inset(24)
        }
    }

    private func configure() {
        titleLabel.stringValue = inspection.title
        subtitleLabel.stringValue = inspection.sourceURL.path
        overviewRows = makeOverviewRows()
        overviewTableView.reloadData()
        profileRootNode = inspection.parsedProfile.map {
            InspectorNodeBuilder.makeRootNode(from: $0.plist, certificates: $0.certificates)
        }
        infoRootNode = inspection.infoPlist.map {
            InspectorNodeBuilder.makeRootNode(from: $0, certificates: [])
        }

        if inspection.parsedProfile == nil {
            segmentedControl.setEnabled(false, forSegment: 1)
        }
        if inspection.infoPlist == nil {
            segmentedControl.setEnabled(false, forSegment: 2)
        }

        updateOutlineForSelectedSegment()
    }

    @objc private func segmentChanged(_ sender: Any?) {
        updateOutlineForSelectedSegment()
    }

    private func updateOutlineForSelectedSegment() {
        let selectedSegment = segmentedControl.selectedSegment
        tabView.selectTabViewItem(at: max(0, selectedSegment))
        overviewTableView.reloadData()
        profileOutlineView.reloadData()
        infoOutlineView.reloadData()
        profileOutlineView.expandItem(nil, expandChildren: true)
        infoOutlineView.expandItem(nil, expandChildren: true)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === overviewTableView {
            return overviewRows.count
        }
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard tableView === overviewTableView,
              let tableColumn,
              overviewRows.indices.contains(row)
        else { return nil }

        let rowModel = overviewRows[row]
        let identifier = NSUserInterfaceItemIdentifier("PreviewOverviewCell.\(tableColumn.identifier.rawValue)")
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

        if tableColumn.identifier.rawValue == "overviewKey" {
            cell.textField?.stringValue = rowModel.key
            cell.textField?.font = .systemFont(ofSize: 12, weight: .medium)
            cell.textField?.textColor = .labelColor
        } else {
            cell.textField?.stringValue = rowModel.value
            cell.textField?.font = .systemFont(ofSize: 12)
            cell.textField?.textColor = .secondaryLabelColor
        }

        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let node = (item as? InspectorNode) ?? rootNode(for: outlineView)
        return node?.children.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? InspectorNode else { return false }
        return !node.children.isEmpty
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let node = (item as? InspectorNode) ?? rootNode(for: outlineView)
        return node!.children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? InspectorNode,
              let tableColumn
        else { return nil }

        let identifier = NSUserInterfaceItemIdentifier("PreviewOutlineCell.\(tableColumn.identifier.rawValue)")
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
            cell.textField?.font = .systemFont(ofSize: 11, weight: .regular)
            cell.textField?.textColor = .secondaryLabelColor
        default:
            cell.textField?.stringValue = node.detail
            cell.textField?.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            cell.textField?.textColor = .secondaryLabelColor
        }

        return cell
    }

    @objc private func copySelectedOverviewRows(_ sender: Any?) {
        let rows = selectedOverviewRows()
        guard !rows.isEmpty else { return }
        let text = rows
            .map { "\($0.key)\t\($0.value)" }
            .joined(separator: "\n")
        copyTextToPasteboard(text)
    }

    @objc private func copySelectedProfileRows(_ sender: Any?) {
        let nodes = selectedInspectorNodes(in: profileOutlineView)
        guard !nodes.isEmpty else { return }
        copyTextToPasteboard(nodes.map(inspectorClipboardString(for:)).joined(separator: "\n"))
    }

    @objc private func copySelectedInfoRows(_ sender: Any?) {
        let nodes = selectedInspectorNodes(in: infoOutlineView)
        guard !nodes.isEmpty else { return }
        copyTextToPasteboard(nodes.map(inspectorClipboardString(for:)).joined(separator: "\n"))
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if menu === overviewContextMenu {
            let item = NSMenuItem(title: "复制选中行", action: #selector(copySelectedOverviewRows(_:)), keyEquivalent: "")
            item.target = self
            item.isEnabled = !selectedOverviewRows().isEmpty
            menu.addItem(item)
            return
        }

        let action: Selector
        let hasSelection: Bool
        if menu === profileContextMenu {
            action = #selector(copySelectedProfileRows(_:))
            hasSelection = !selectedInspectorNodes(in: profileOutlineView).isEmpty
        } else {
            action = #selector(copySelectedInfoRows(_:))
            hasSelection = !selectedInspectorNodes(in: infoOutlineView).isEmpty
        }

        let item = NSMenuItem(title: "复制选中行", action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = hasSelection
        menu.addItem(item)
    }

    private func configureOverviewTableView() {
        overviewTableView.headerView = nil
        overviewTableView.usesAlternatingRowBackgroundColors = false
        overviewTableView.selectionHighlightStyle = .regular
        overviewTableView.allowsMultipleSelection = true
        overviewTableView.rowHeight = 30
        overviewTableView.dataSource = self
        overviewTableView.delegate = self

        let keyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("overviewKey"))
        keyColumn.width = 180
        keyColumn.minWidth = 120
        let valueColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("overviewValue"))
        valueColumn.width = 560
        valueColumn.minWidth = 240

        overviewTableView.addTableColumn(keyColumn)
        overviewTableView.addTableColumn(valueColumn)
    }

    private func configureOutlineView(_ outlineView: NSOutlineView) {
        outlineView.headerView = nil
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.rowSizeStyle = .medium
        outlineView.allowsMultipleSelection = true
        outlineView.dataSource = self
        outlineView.delegate = self

        let keyColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("key"))
        keyColumn.title = "键"
        keyColumn.width = 260
        let typeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("type"))
        typeColumn.title = "类型"
        typeColumn.width = 120
        let detailColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("detail"))
        detailColumn.title = "值"
        detailColumn.width = 460
        outlineView.addTableColumn(keyColumn)
        outlineView.addTableColumn(typeColumn)
        outlineView.addTableColumn(detailColumn)
        outlineView.outlineTableColumn = keyColumn
    }

    private func selectedOverviewRows() -> [PreviewOverviewRow] {
        let indexes = effectiveSelectedIndexes(in: overviewTableView)
        return indexes.compactMap { index in
            guard overviewRows.indices.contains(index) else { return nil }
            return overviewRows[index]
        }
    }

    private func selectedInspectorNodes(in outlineView: NSOutlineView) -> [InspectorNode] {
        let indexes = effectiveSelectedIndexes(in: outlineView)
        return indexes.compactMap { outlineView.item(atRow: $0) as? InspectorNode }
    }

    private func effectiveSelectedIndexes(in tableView: NSTableView) -> IndexSet {
        if !tableView.selectedRowIndexes.isEmpty {
            return tableView.selectedRowIndexes
        }
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0 else { return [] }
        return IndexSet(integer: clickedRow)
    }

    private func effectiveSelectedIndexes(in outlineView: NSOutlineView) -> IndexSet {
        if !outlineView.selectedRowIndexes.isEmpty {
            return outlineView.selectedRowIndexes
        }
        let clickedRow = outlineView.clickedRow
        guard clickedRow >= 0 else { return [] }
        return IndexSet(integer: clickedRow)
    }

    private func inspectorClipboardString(for node: InspectorNode) -> String {
        let parts = [node.key, node.type, node.detail]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: "\t")
    }

    private func copyTextToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func rootNode(for outlineView: NSOutlineView) -> InspectorNode? {
        if outlineView === profileOutlineView {
            return profileRootNode
        }
        return infoRootNode
    }

    private func makeOverviewRows() -> [PreviewOverviewRow] {
        let record = inspection.parsedProfile?.record
        let bundleIdentifier = record?.bundleIdentifier
            ?? (inspection.infoPlist?["CFBundleIdentifier"] as? String)
            ?? "-"
        let teamName = record?.teamName ?? "-"
        let typeName = record?.profileType ?? fallbackFileTypeDescription(for: inspection.sourceURL)
        let platformName = record?.profilePlatform
            ?? (inspection.infoPlist?["DTPlatformName"] as? String)
            ?? "-"
        let expiration = record?.expirationDateValue.map(Formatters.timestampString(from:)) ?? "-"
        let embeddedProfile = record?.displayName ?? "无嵌入描述文件"
        let infoAvailability = inspection.infoPlist == nil ? "无" : "有"

        return [
            PreviewOverviewRow(key: "文件", value: inspection.sourceURL.lastPathComponent),
            PreviewOverviewRow(key: "名称", value: inspection.title),
            PreviewOverviewRow(key: "Bundle ID", value: bundleIdentifier),
            PreviewOverviewRow(key: "团队", value: teamName),
            PreviewOverviewRow(key: "类型", value: typeName),
            PreviewOverviewRow(key: "平台", value: platformName),
            PreviewOverviewRow(key: "到期", value: expiration),
            PreviewOverviewRow(key: "证书", value: "\(record?.certificateCount ?? 0)"),
            PreviewOverviewRow(key: "设备", value: "\(record?.deviceCount ?? 0)"),
            PreviewOverviewRow(key: "描述文件", value: embeddedProfile),
            PreviewOverviewRow(key: "Info.plist", value: infoAvailability),
        ]
    }

    private func fallbackFileTypeDescription(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "ipa":
            return "IPA"
        case "xcarchive":
            return "XCArchive"
        case "app":
            return "APP"
        case "appex":
            return "APPEX"
        case "mobileprovision":
            return "iOS Profile"
        case "provisionprofile":
            return "Mac Profile"
        default:
            return "文件"
        }
    }
}

#if DEBUG
extension PreviewWindowController {
    var debugSegmentedControl: NSSegmentedControl { segmentedControl }
    var debugOverviewTableView: NSTableView { overviewTableView }
    var debugProfileOutlineView: NSOutlineView { profileOutlineView }
    var debugInfoOutlineView: NSOutlineView { infoOutlineView }
    var debugOverviewRows: [String] { overviewRows.map { "\($0.key): \($0.value)" } }
    var debugTitleLabel: NSTextField { titleLabel }

    func debugSelectSegment(_ index: Int) {
        segmentedControl.selectedSegment = index
        updateOutlineForSelectedSegment()
    }

    func debugSelectOverviewRows(_ indexes: IndexSet) {
        overviewTableView.selectRowIndexes(indexes, byExtendingSelection: false)
    }

    func debugSelectProfileRows(_ indexes: IndexSet) {
        profileOutlineView.selectRowIndexes(indexes, byExtendingSelection: false)
    }

    func debugCopyOverviewSelection() {
        copySelectedOverviewRows(nil)
    }

    func debugCopyProfileSelection() {
        copySelectedProfileRows(nil)
    }
}
#endif

private final class CopyableTableView: NSTableView {
    var copyHandler: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "c" {
            copy(self)
            return
        }

        super.keyDown(with: event)
    }

    @objc func copy(_ sender: Any?) {
        copyHandler?()
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(copy(_:)) {
            return selectedRowIndexes.isEmpty == false || clickedRow >= 0
        }

        return super.validateUserInterfaceItem(item)
    }
}

private final class CopyableOutlineView: NSOutlineView {
    var copyHandler: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "c" {
            copy(self)
            return
        }

        super.keyDown(with: event)
    }

    @objc func copy(_ sender: Any?) {
        copyHandler?()
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(copy(_:)) {
            return selectedRowIndexes.isEmpty == false || clickedRow >= 0
        }

        return super.validateUserInterfaceItem(item)
    }
}

private final class PreviewWebView: WKWebView {
    init() {
        super.init(frame: .zero, configuration: Self.makeConfiguration())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        nil
    }

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        menu.removeAllItems()
    }

    @objc override func reload(_ sender: Any?) {}

    @objc override func reloadFromOrigin(_ sender: Any?) {}

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(reload(_:)) || item.action == #selector(reloadFromOrigin(_:)) {
            return false
        }

        return super.validateUserInterfaceItem(item)
    }

    private static func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        let disableContextMenuScript = WKUserScript(
            source: """
            document.addEventListener('contextmenu', function(event) {
                event.preventDefault();
            }, true);
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(disableContextMenuScript)
        configuration.userContentController = userContentController
        return configuration
    }
}

final class HTMLPreviewView: NSView {
    private let webView = PreviewWebView()
    #if DEBUG
    private var debugPlainTextStorage = ""
    #endif

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadHTMLString(_ html: String, baseURL: URL?) {
        #if DEBUG
        debugPlainTextStorage = Self.plainText(from: html)
        #endif
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    private func buildUI() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.75).cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false

        addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private static func plainText(from html: String) -> String {
        html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    #if DEBUG
    var debugPlainText: String {
        debugPlainTextStorage
    }

    var debugReloadActionEnabled: Bool {
        webView.validateUserInterfaceItem(DebugValidatedUserInterfaceItem(action: #selector(PreviewWebView.reload(_:))))
    }
    #endif
}

#if DEBUG
private final class DebugValidatedUserInterfaceItem: NSObject, NSValidatedUserInterfaceItem {
    let action: Selector?

    init(action: Selector?) {
        self.action = action
    }

    var tag: Int { 0 }
}
#endif
