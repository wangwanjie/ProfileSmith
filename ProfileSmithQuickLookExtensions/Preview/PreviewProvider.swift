import AppKit
import QuickLookUI

final class PreviewViewController: NSViewController, QLPreviewingController {
    private let inspector = ProfileSmithQuickLookInspector()
    private let previewView = QuickLookNativePreviewView()

    override func loadView() {
        view = previewView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        preferredContentSize = NSSize(width: 920, height: 1180)

        do {
            let inspection = try inspector.inspect(url: url)
            previewView.render(inspection: inspection)
        } catch {
            previewView.render(error: error, fileURL: url)
        }

        handler(nil)
    }
}

private final class QuickLookNativePreviewView: NSView {
    private let scrollView = NSScrollView()
    private let documentView = FlippedView()
    private let contentStack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateBackgroundColor()
    }

    func render(inspection: QuickLookInspection) {
        contentStack.removeAllArrangedSubviews()
        addContentView(makeHeaderCard(for: inspection))
        addContentView(
            makeRowsCard(
                title: "概要",
                subtitle: "覆盖描述文件、嵌入签名和核心有效期信息。",
                rows: inspection.summaryRows,
                emptyText: "没有可显示的概要信息。"
            )
        )
        addContentView(
            makeRowsCard(
                title: "Entitlements",
                subtitle: "优先展示应用标识、设备能力与调试权限。",
                rows: inspection.entitlementRows,
                emptyText: "没有可显示的 Entitlements。"
            )
        )
        addContentView(
            makeRowsCard(
                title: "Info.plist",
                subtitle: "仅在 IPA、App、XCArchive 或 APPEX 内解析到 Info.plist 时显示。",
                rows: inspection.infoRows,
                emptyText: "没有可显示的 Info.plist 数据。"
            )
        )
        addContentView(
            makeRowsCard(
                title: "证书摘要",
                subtitle: "展示签名证书主题和 SHA-1 摘要。",
                rows: inspection.certificateRows,
                emptyText: "没有可显示的证书摘要。"
            )
        )
    }

    func render(error: Error, fileURL: URL) {
        contentStack.removeAllArrangedSubviews()

        let card = QuickLookCardView(accentColor: .systemRed)
        card.addArrangedSubview(makePillRow(primaryText: "Quick Look", primaryColor: .systemRed, primaryFillColor: .systemRed.withAlphaComponent(0.14), secondaryText: "无法解析"))
        card.addArrangedSubview(makeTitleLabel("无法预览 \(fileURL.lastPathComponent)"))
        card.addArrangedSubview(makeBodyLabel(fileURL.path, color: .secondaryLabelColor, selectable: true, lineBreakMode: .byCharWrapping))
        card.addArrangedSubview(makeBodyLabel(error.localizedDescription, color: .labelColor, selectable: true, lineBreakMode: .byWordWrapping))
        addContentView(card)
    }

    private func buildUI() {
        translatesAutoresizingMaskIntoConstraints = false
        updateBackgroundColor()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        documentView.translatesAutoresizingMaskIntoConstraints = false

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16

        addSubview(scrollView)
        scrollView.documentView = documentView
        documentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor, constant: -20),
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor, constant: -28),
        ])
    }

    private func updateBackgroundColor() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    }

    private func addContentView(_ view: NSView) {
        contentStack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    private func makeHeaderCard(for inspection: QuickLookInspection) -> QuickLookCardView {
        let card = QuickLookCardView(accentColor: inspection.fileKind.accentColor)
        card.addArrangedSubview(
            makePillRow(
                primaryText: inspection.fileKind.badgeText,
                primaryColor: inspection.fileKind.accentColor,
                primaryFillColor: inspection.fileKind.tintColor,
                secondaryText: inspection.statusText
            )
        )
        card.addArrangedSubview(makeTitleLabel(inspection.title))
        card.addArrangedSubview(makeBodyLabel(inspection.fileURL.path, color: .secondaryLabelColor, selectable: true, lineBreakMode: .byCharWrapping))
        card.addArrangedSubview(makeBodyLabel(inspection.headerDescription, color: .secondaryLabelColor))
        return card
    }

    private func makeRowsCard(title: String, subtitle: String, rows: [QuickLookFieldRow], emptyText: String) -> QuickLookCardView {
        let card = QuickLookCardView()
        card.addArrangedSubview(makeSectionTitleLabel(title))
        card.addArrangedSubview(makeBodyLabel(subtitle, color: .secondaryLabelColor))
        if rows.isEmpty {
            card.addArrangedSubview(makeBodyLabel(emptyText, color: .secondaryLabelColor))
        } else {
            card.addArrangedSubview(QuickLookKeyValueListView(rows: rows))
        }
        return card
    }

    private func makePillRow(primaryText: String, primaryColor: NSColor, primaryFillColor: NSColor, secondaryText: String) -> NSStackView {
        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.addArrangedSubview(QuickLookPillView(text: primaryText, textColor: primaryColor, fillColor: primaryFillColor))
        row.addArrangedSubview(
            QuickLookPillView(
                text: secondaryText,
                textColor: .secondaryLabelColor,
                fillColor: NSColor.separatorColor.withAlphaComponent(0.12)
            )
        )
        return row
    }

    private func makeTitleLabel(_ string: String) -> NSTextField {
        let field = NSTextField(labelWithString: string)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = NSFont(name: "Avenir Next Demi Bold", size: 30) ?? .systemFont(ofSize: 30, weight: .semibold)
        field.textColor = .labelColor
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        return field
    }

    private func makeSectionTitleLabel(_ string: String) -> NSTextField {
        let field = NSTextField(labelWithString: string)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.font = .systemFont(ofSize: 18, weight: .semibold)
        field.textColor = .labelColor
        return field
    }

    private func makeBodyLabel(
        _ string: String,
        color: NSColor,
        selectable: Bool = false,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) -> QuickLookSelectableTextField {
        let field = QuickLookSelectableTextField(
            font: .systemFont(ofSize: 13),
            textColor: color,
            selectable: selectable,
            lineBreakMode: lineBreakMode
        )
        field.stringValue = string
        return field
    }
}

private final class QuickLookCardView: NSView {
    private let accentColor: NSColor?
    private let accentBar = NSView()
    private let accentBarWidthConstraint: NSLayoutConstraint
    private let stackView = NSStackView()

    init(accentColor: NSColor? = nil) {
        self.accentColor = accentColor
        self.accentBarWidthConstraint = accentBar.widthAnchor.constraint(equalToConstant: accentColor == nil ? 0 : 5)
        super.init(frame: .zero)
        buildUI()
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    func addArrangedSubview(_ view: NSView) {
        stackView.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
    }

    private func buildUI() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.masksToBounds = true
        layer?.borderWidth = 1

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.wantsLayer = true

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)

        addSubview(accentBar)
        addSubview(stackView)

        accentBarWidthConstraint.isActive = true

        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            accentBar.topAnchor.constraint(equalTo: topAnchor),
            accentBar.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func updateColors() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.98).cgColor
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.45).cgColor
        accentBar.layer?.backgroundColor = accentColor?.cgColor
    }
}

private final class QuickLookKeyValueListView: NSView {
    init(rows: [QuickLookFieldRow]) {
        super.init(frame: .zero)
        buildUI(rows: rows)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI(rows: [QuickLookFieldRow]) {
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = NSStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        for index in rows.indices {
            let rowView = QuickLookKeyValueRowView(
                row: rows[index],
                showsDivider: index < rows.count - 1
            )
            stackView.addArrangedSubview(rowView)
            rowView.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }
    }
}

private final class QuickLookKeyValueRowView: NSView {
    init(row: QuickLookFieldRow, showsDivider: Bool) {
        super.init(frame: .zero)
        buildUI(row: row, showsDivider: showsDivider)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildUI(row: QuickLookFieldRow, showsDivider: Bool) {
        translatesAutoresizingMaskIntoConstraints = false

        let keyField = QuickLookSelectableTextField(
            font: .systemFont(ofSize: 12, weight: .semibold),
            textColor: .secondaryLabelColor,
            selectable: true,
            lineBreakMode: .byWordWrapping
        )
        keyField.stringValue = row.title
        keyField.setContentHuggingPriority(.required, for: .horizontal)
        keyField.widthAnchor.constraint(equalToConstant: 140).isActive = true

        let valueFont: NSFont = row.isCode
            ? .monospacedSystemFont(ofSize: 12, weight: .regular)
            : .systemFont(ofSize: 13)
        let valueField = QuickLookSelectableTextField(
            font: valueFont,
            textColor: .labelColor,
            selectable: true,
            lineBreakMode: row.isCode ? .byCharWrapping : .byWordWrapping
        )
        valueField.stringValue = row.value

        let rowStack = NSStackView(views: [keyField, valueField])
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.orientation = .horizontal
        rowStack.alignment = .top
        rowStack.spacing = 14
        rowStack.distribution = .fill

        addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: showsDivider ? -11 : -10),
        ])

        if showsDivider {
            let divider = NSView()
            divider.translatesAutoresizingMaskIntoConstraints = false
            divider.wantsLayer = true
            divider.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.3).cgColor
            addSubview(divider)
            NSLayoutConstraint.activate([
                divider.leadingAnchor.constraint(equalTo: leadingAnchor),
                divider.trailingAnchor.constraint(equalTo: trailingAnchor),
                divider.bottomAnchor.constraint(equalTo: bottomAnchor),
                divider.heightAnchor.constraint(equalToConstant: 1),
            ])
        }
    }
}

private final class QuickLookSelectableTextField: NSTextField {
    init(
        font: NSFont,
        textColor: NSColor,
        selectable: Bool,
        lineBreakMode: NSLineBreakMode
    ) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.font = font
        self.textColor = textColor
        isBordered = false
        isEditable = false
        isSelectable = selectable
        drawsBackground = false
        usesSingleLineMode = false
        allowsEditingTextAttributes = false
        maximumNumberOfLines = 0
        self.lineBreakMode = lineBreakMode
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class QuickLookPillView: NSView {
    private let fillColor: NSColor
    private let textColor: NSColor
    private let label = NSTextField(labelWithString: "")

    init(text: String, textColor: NSColor, fillColor: NSColor) {
        self.fillColor = fillColor
        self.textColor = textColor
        super.init(frame: .zero)
        label.stringValue = text
        buildUI()
        updateColors()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func buildUI() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 999

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.alignment = .center

        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }

    private func updateColors() {
        layer?.backgroundColor = fillColor.cgColor
        label.textColor = textColor
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

private extension NSStackView {
    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach { subview in
            removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }
}
