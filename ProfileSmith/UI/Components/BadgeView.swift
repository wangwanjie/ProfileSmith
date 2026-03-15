import Cocoa
import SnapKit

final class BadgeView: NSView {
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10

        label.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        label.alignment = .center
        addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10))
        }
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(text: String?, fillColor: NSColor, textColor: NSColor = .labelColor) {
        guard let text, !text.isEmpty else {
            isHidden = true
            return
        }

        isHidden = false
        label.stringValue = text
        label.textColor = textColor
        layer?.backgroundColor = fillColor.cgColor
    }
}
