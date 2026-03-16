import AppKit

@main
@MainActor
enum ProfileSmithApplication {
    private static let appDelegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.delegate = appDelegate
        application.run()
    }
}
