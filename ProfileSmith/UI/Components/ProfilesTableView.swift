import Cocoa

final class TrailingBorderlessTableHeaderCell: NSTableHeaderCell {
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.draw(withFrame: cellFrame, in: controlView)

        let separatorRect = NSRect(
            x: max(cellFrame.minX, cellFrame.maxX - 1),
            y: cellFrame.minY,
            width: min(1, cellFrame.width),
            height: cellFrame.height
        )
        guard separatorRect.width > 0 else { return }

        NSColor.controlBackgroundColor.setFill()
        separatorRect.fill()
    }
}

final class ProfilesTableView: NSTableView {
    var quickLookHandler: (() -> Void)?
    var copyHandler: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "c" {
            copy(self)
            return
        }

        if event.keyCode == 49 {
            quickLookHandler?()
            return
        }

        super.keyDown(with: event)
    }

    @objc func copy(_ sender: Any?) {
        copyHandler?()
    }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(copy(_:)) {
            return selectedRowIndexes.isEmpty == false
        }

        return super.validateUserInterfaceItem(item)
    }
}
