import Cocoa
import SnapKit

private struct PreviewOverviewRow {
    let key: String
    let value: String
}

final class PreviewWindowController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let inspection: PreviewInspection
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let segmentedControl = NSSegmentedControl(labels: ["总览", "描述文件", "Info.plist"], trackingMode: .selectOne, target: nil, action: nil)
    private let tabView = NSTabView()
    private let overviewTableView = NSTableView()
    private let overviewScrollView = NSScrollView()
    private let profileOutlineView = NSOutlineView()
    private let profileOutlineScrollView = NSScrollView()
    private let infoOutlineView = NSOutlineView()
    private let infoOutlineScrollView = NSScrollView()
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

    private func configureOverviewTableView() {
        overviewTableView.headerView = nil
        overviewTableView.usesAlternatingRowBackgroundColors = false
        overviewTableView.selectionHighlightStyle = .none
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
    var debugProfileOutlineView: NSOutlineView { profileOutlineView }
    var debugInfoOutlineView: NSOutlineView { infoOutlineView }
    var debugOverviewRows: [String] { overviewRows.map { "\($0.key): \($0.value)" } }
    var debugTitleLabel: NSTextField { titleLabel }

    func debugSelectSegment(_ index: Int) {
        segmentedControl.selectedSegment = index
        updateOutlineForSelectedSegment()
    }
}
#endif

final class HTMLPreviewView: NSView {
    private let scrollView = NSScrollView()
    private let textView = NSTextView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadHTMLString(_ html: String, baseURL _: URL?) {
        textView.textStorage?.setAttributedString(Self.attributedString(from: html))
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func buildUI() {
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.drawsBackground = false

        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = false
        textView.textContainerInset = NSSize(width: 18, height: 18)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]

        scrollView.documentView = textView
        addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private static func attributedString(from html: String) -> NSAttributedString {
        guard let data = html.data(using: .utf8) else {
            return NSAttributedString(string: html)
        }

        do {
            let attributedString = try NSMutableAttributedString(
                data: data,
                options: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                ],
                documentAttributes: nil
            )
            let fullRange = NSRange(location: 0, length: attributedString.length)
            attributedString.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                guard let font = value as? NSFont else { return }
                let pointSize = font.pointSize == 12 ? CGFloat(13) : font.pointSize
                attributedString.addAttribute(.font, value: NSFont.systemFont(ofSize: pointSize), range: range)
            }
            attributedString.removeAttribute(.backgroundColor, range: fullRange)
            return attributedString
        } catch {
            return NSAttributedString(string: html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
        }
    }

    #if DEBUG
    var debugPlainText: String {
        textView.string
    }
    #endif
}
