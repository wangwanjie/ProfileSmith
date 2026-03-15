import Cocoa

final class ProfilesTableView: NSTableView {
    var quickLookHandler: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 {
            quickLookHandler?()
            return
        }

        super.keyDown(with: event)
    }
}
