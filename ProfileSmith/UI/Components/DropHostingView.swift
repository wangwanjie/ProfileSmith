import Cocoa

protocol DropHostingViewDelegate: AnyObject {
    func dropHostingView(_ view: DropHostingView, didReceiveFileURLs urls: [URL])
}

final class DropHostingView: NSView {
    weak var delegate: DropHostingViewDelegate?
    var onEffectiveAppearanceChange: (() -> Void)?

    private var isDropTargeted = false {
        didSet {
            guard oldValue != isDropTargeted else { return }
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard isDropTargeted else { return }

        let rect = bounds.insetBy(dx: 18, dy: 18)
        let path = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
        NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        path.fill()

        let stroke = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
        stroke.setLineDash([10, 8], count: 2, phase: 0)
        stroke.lineWidth = 2
        NSColor.controlAccentColor.setStroke()
        stroke.stroke()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = extractFileURLs(from: sender)
        guard !urls.isEmpty, urls.contains(where: Self.supportsFileURL(_:)) else {
            isDropTargeted = false
            return []
        }
        isDropTargeted = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDropTargeted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDropTargeted = false
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = extractFileURLs(from: sender).filter(Self.supportsFileURL(_:))
        guard !urls.isEmpty else { return false }
        delegate?.dropHostingView(self, didReceiveFileURLs: urls)
        return true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onEffectiveAppearanceChange?()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onEffectiveAppearanceChange?()
    }

    private func extractFileURLs(from draggingInfo: NSDraggingInfo) -> [URL] {
        let classes: [AnyClass] = [NSURL.self]
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return draggingInfo.draggingPasteboard.readObjects(forClasses: classes, options: options) as? [URL] ?? []
    }

    nonisolated static func supportsFileURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["mobileprovision", "provisionprofile", "ipa", "xcarchive", "appex", "app"].contains(ext)
    }
}
