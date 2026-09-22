import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let model: WebShellModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = model.webView
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        model.loadIfNeeded()
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let model: WebShellModel

        init(model: WebShellModel) {
            self.model = model
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
        ) {
            // A nil targetFrame means a new window, which we treat as a main-frame navigation.
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
            switch model.policy.decide(url: navigationAction.request.url, isMainFrame: isMainFrame) {
            case .allow:
                decisionHandler(.allow)
            case .openExternally:
                if let url = navigationAction.request.url { UIApplication.shared.open(url) }
                decisionHandler(.cancel)
            case .cancel:
                decisionHandler(.cancel)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url else { return nil }
            switch model.policy.decide(url: url, isMainFrame: true) {
            case .allow:
                webView.load(navigationAction.request)
            case .openExternally:
                UIApplication.shared.open(url)
            case .cancel:
                break
            }
            return nil
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            model.didCommit()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            model.didFail(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            model.didFail(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            model.reloadAfterProcessTermination()
        }

        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping @MainActor (WKPermissionDecision) -> Void
        ) {
            let allowed = type == .microphone && model.policy.isAppOrigin(scheme: origin.protocol, host: origin.host)
            decisionHandler(allowed ? .grant : .deny)
        }

        // Without these, WKWebView drops alert() and confirm() returns false; the web app uses confirm() before destructive actions.
        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping @MainActor () -> Void
        ) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            present(alert, from: webView, orElse: completionHandler)
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping @MainActor (Bool) -> Void
        ) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
            present(alert, from: webView) { completionHandler(false) }
        }

        private func present(_ alert: UIAlertController, from webView: WKWebView, orElse fallback: () -> Void) {
            var presenter = webView.window?.rootViewController
            while let next = presenter?.presentedViewController { presenter = next }
            guard let presenter else { return fallback() }
            presenter.present(alert, animated: true)
        }
    }
}
