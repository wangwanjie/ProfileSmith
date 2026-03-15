import Cocoa

final class MainWindowController: NSWindowController, NSWindowDelegate {
    let contentController: MainViewController

    init(context: AppContext) {
        contentController = MainViewController(context: context)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 840),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ProfileSmith"
        window.center()
        window.minSize = NSSize(width: 1100, height: 720)
        window.contentViewController = contentController
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false

        super.init(window: window)
        shouldCascadeWindows = false
        windowFrameAutosaveName = "ProfileSmith.MainWindow"
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
