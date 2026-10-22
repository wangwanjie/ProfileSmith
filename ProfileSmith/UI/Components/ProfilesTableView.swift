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
    var previewHandler: (() -> Void)?
    var copyHandler: (() -> Void)?
    var deleteHandler: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifierFlags.contains(.command), event.charactersIgnoringModifiers?.lowercased() == "c" {
            copy(self)
            return
        }

        // 空格：快速预览
        if event.keyCode == 49 {
            previewHandler?()
            return
        }

        // Delete（51）或 ⌘Delete：移到废纸篓（处理函数内部会弹窗确认）
        if event.keyCode == 51 || event.keyCode == 117 {
            if !selectedRowIndexes.isEmpty {
                deleteHandler?()
                return
            }
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
