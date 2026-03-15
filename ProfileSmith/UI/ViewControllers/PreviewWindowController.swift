import Cocoa
import SnapKit
import WebKit

final class PreviewWindowController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    private let inspection: PreviewInspection
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let segmentedControl = NSSegmentedControl(labels: ["总览", "描述文件", "Info.plist"], trackingMode: .selectOne, target: nil, action: nil)
    private let tabView = NSTabView()
    private let webView = WKWebView(frame: .zero)
    private let profileOutlineView = NSOutlineView()
    private let profileOutlineScrollView = NSScrollView()
    private let infoOutlineView = NSOutlineView()
    private let infoOutlineScrollView = NSScrollView()
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

        let webContainer = NSView()
        webContainer.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        configureOutlineView(profileOutlineView)
        configureOutlineView(infoOutlineView)

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
        overviewTab.view = webContainer
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
        webView.loadHTMLString(inspection.quickLookHTML, baseURL: nil)
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
        profileOutlineView.reloadData()
        infoOutlineView.reloadData()
        profileOutlineView.expandItem(nil, expandChildren: true)
        infoOutlineView.expandItem(nil, expandChildren: true)
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
}

#if DEBUG
extension PreviewWindowController {
    var debugSegmentedControl: NSSegmentedControl { segmentedControl }
    var debugProfileOutlineView: NSOutlineView { profileOutlineView }
    var debugInfoOutlineView: NSOutlineView { infoOutlineView }
    var debugTitleLabel: NSTextField { titleLabel }

    func debugSelectSegment(_ index: Int) {
        segmentedControl.selectedSegment = index
        updateOutlineForSelectedSegment()
    }
}
#endif
