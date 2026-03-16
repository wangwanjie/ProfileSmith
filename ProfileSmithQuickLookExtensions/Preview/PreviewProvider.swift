import AppKit
import QuickLookUI
import WebKit

final class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {
    private let inspector = ProfileSmithQuickLookInspector()
    private let webView = WKWebView(frame: .zero)
    private var completionHandler: ((Error?) -> Void)?
    private var pendingError: Error?

    override func loadView() {
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        view = webView
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        completionHandler = handler

        do {
            let inspection = try inspector.inspect(url: url)
            preferredContentSize = NSSize(width: 980, height: 1240)
            webView.loadHTMLString(inspection.html(), baseURL: nil)
        } catch {
            pendingError = error
            webView.loadHTMLString(Self.errorHTML(for: error), baseURL: nil)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let callback = completionHandler
        completionHandler = nil
        let error = pendingError
        pendingError = nil
        callback?(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let callback = completionHandler
        completionHandler = nil
        pendingError = nil
        callback?(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let callback = completionHandler
        completionHandler = nil
        pendingError = nil
        callback?(error)
    }

    private static func errorHTML(for error: Error) -> String {
        let message = (error as NSError).localizedDescription
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return """
        <!doctype html>
        <html>
        <body style="margin:0;padding:24px;font-family:-apple-system,BlinkMacSystemFont,'Helvetica Neue',sans-serif;background:#f6f8fb;color:#152033;">
            <h2 style="margin:0 0 12px;font-size:22px;">ProfileSmith Quick Look</h2>
            <p style="margin:0;font-size:14px;line-height:1.6;">\(message)</p>
        </body>
        </html>
        """
    }
}
