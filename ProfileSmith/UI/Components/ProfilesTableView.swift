import Cocoa

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
