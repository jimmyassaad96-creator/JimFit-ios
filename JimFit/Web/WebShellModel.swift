import Observation
import UIKit
import WebKit

@Observable
final class WebShellModel {
    private(set) var progress: Double = 0
    private(set) var isLoading = false
    private(set) var loadError: String?

    // Owned here rather than by the representable so SwiftUI re-renders never recreate it. Built on first
    // use, not in init: the app creates this model in App.init, before UIKit has a scene, and a WKWebView
    // made that early crashes UIKit's gesture handling on the first tap into the page.
    @ObservationIgnored private(set) lazy var webView: WKWebView = makeWebView()
    @ObservationIgnored let policy: NavigationPolicy
    @ObservationIgnored private let baseURL: URL
    @ObservationIgnored private var failedURL: URL?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    init(baseURL: URL) {
        self.baseURL = baseURL
        policy = NavigationPolicy(baseURL: baseURL)
    }

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true
        config.applicationNameForUserAgent = [config.applicationNameForUserAgent, "JimFitiOS/\(AppConfig.version)"]
            .compactMap { $0 }
            .joined(separator: " ")

        let webView = WKWebView(frame: .zero, configuration: config)
        let background = UIColor(named: "Background")
        // Non-opaque so the background colour shows before first paint instead of white.
        webView.isOpaque = false
        webView.backgroundColor = background
        webView.scrollView.backgroundColor = background
        webView.underPageBackgroundColor = background
        webView.allowsBackForwardNavigationGestures = true
        // The page applies env(safe-area-inset-*) itself; letting UIKit inset too would double it.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        #if DEBUG
        webView.isInspectable = true
        #endif

        // WKWebView posts KVO on the main thread.
        observations = [
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.progress = webView.estimatedProgress }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.isLoading = webView.isLoading }
            },
        ]
        return webView
    }

    func loadIfNeeded() {
        guard webView.url == nil, !webView.isLoading else { return }
        webView.load(URLRequest(url: baseURL))
    }

    func retry() {
        let url = failedURL ?? webView.url ?? baseURL
        loadError = nil
        failedURL = nil
        webView.load(URLRequest(url: url))
    }

    func reloadAfterProcessTermination() {
        if webView.url == nil {
            webView.load(URLRequest(url: baseURL))
        } else {
            webView.reload()
        }
    }

    func didCommit() {
        loadError = nil
        failedURL = nil
    }

    func didFail(_ error: Error) {
        let error = error as NSError
        guard !Self.isIgnorable(error) else { return }
        failedURL = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL
        loadError = error.localizedDescription
    }

    nonisolated static func isIgnorable(_ error: NSError) -> Bool {
        // 102 is WebKit's "frame load interrupted", raised whenever the policy cancels a navigation.
        (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)
            || (error.domain == "WebKitErrorDomain" && error.code == 102)
    }
}
