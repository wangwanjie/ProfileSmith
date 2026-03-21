import Cocoa
import Combine

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private enum Constants {
        static let autosaveName = "ProfileSmith.MainWindow"
    }

    let contentController: MainViewController
    private var cancellables = Set<AnyCancellable>()

    init(context: AppContext) {
        contentController = MainViewController(context: context)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1320, height: 840),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.appName
        window.center()
        window.minSize = NSSize(width: 1100, height: 720)
        window.contentViewController = contentController
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false

        super.init(window: window)
        shouldCascadeWindows = false
        window.setFrameAutosaveName(Constants.autosaveName)
        window.delegate = self
        bindLocalization()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        guard let window else { return }
        recenterWindowIfNeeded(window)
        window.makeKeyAndOrderFront(sender)
        window.orderFrontRegardless()
    }

    private func recenterWindowIfNeeded(_ window: NSWindow) {
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        guard !visibleFrames.contains(where: { $0.intersects(window.frame) }) else { return }

        if let screen = NSScreen.main ?? NSScreen.screens.first {
            let frame = screen.visibleFrame
            let size = window.frame.size
            let centered = NSRect(
                x: frame.midX - (size.width / 2),
                y: frame.midY - (size.height / 2),
                width: size.width,
                height: size.height
            )
            window.setFrame(centered, display: false)
            return
        }

        window.center()
    }

    private func bindLocalization() {
        AppLocalization.shared.$language
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.window?.title = L10n.appName
            }
            .store(in: &cancellables)
    }
}
