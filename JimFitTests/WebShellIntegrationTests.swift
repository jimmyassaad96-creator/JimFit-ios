import Testing
import UIKit
import WebKit
@testable import JimFit

@MainActor
private func waitUntil(timeout: Duration = .seconds(45), _ condition: () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(250))
    }
    return await condition()
}

private final class CapturingViewController: UIViewController {
    var captured: [UIViewController] = []

    override func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        captured.append(controller)
    }
}

extension UIView {
    fileprivate func firstDescendant<T: UIView>(of type: T.Type) -> T? {
        if let match = self as? T { return match }
        for subview in subviews {
            if let match = subview.firstDescendant(of: type) { return match }
        }
        return nil
    }
}

/// Runs against the host app's own web view, loading the live https://jimfit.app, so it needs network.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(2)))
struct LiveWebShellTests {
    private func appWebView() async throws -> (WKWebView, UIWindow) {
        var found: (WKWebView, UIWindow)?
        _ = await waitUntil {
            let windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .filter { !($0.rootViewController is CapturingViewController) }
            found = windows.lazy.compactMap { window in window.firstDescendant(of: WKWebView.self).map { ($0, window) } }.first
            return found != nil
        }
        let (webView, window) = try #require(found, "the host app never put a WKWebView on screen")

        let rendered = await waitUntil {
            let text = try? await webView.evaluateJavaScript("document.readyState === 'complete' && document.body.innerText") as? String
            return text?.contains("Welcome to JimFit") == true
        }
        try #require(rendered, "jimfit.app did not render its welcome screen")
        return (webView, window)
    }

    @Test func webViewFillsTheWindow() async throws {
        let (webView, window) = try await appWebView()
        let frame = webView.convert(webView.bounds, to: window)
        #expect(frame.height > 0)
        #expect(abs(frame.minY - window.bounds.minY) <= 1)
        #expect(abs(frame.height - window.bounds.height) <= 1)
        #expect(abs(frame.width - window.bounds.width) <= 1)
    }

    @Test func pageLayoutIsFullHeight() async throws {
        let (webView, _) = try await appWebView()
        let result = try await webView.callAsyncJavaScript(
            """
            const probe = document.createElement('div');
            probe.style.cssText = 'position:absolute;top:0;left:0;width:1px;height:100vh;visibility:hidden';
            document.body.appendChild(probe);
            const probeHeight = probe.offsetHeight;
            probe.remove();
            return { inner: innerHeight, probe: probeHeight, root: document.getElementById('root').offsetHeight };
            """,
            contentWorld: .page
        )
        let values = try #require(result as? [String: Double])
        let inner = try #require(values["inner"])
        #expect(inner > 0)
        #expect(abs(inner - webView.bounds.height) <= 1)
        #expect(values["probe"] == inner)
        #expect(try #require(values["root"]) >= inner)
    }

    @Test func userAgentIdentifiesTheShell() async throws {
        let (webView, _) = try await appWebView()
        let userAgent = try #require(try await webView.evaluateJavaScript("navigator.userAgent") as? String)
        let version = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        #expect(userAgent.hasSuffix("JimFitiOS/\(version)"), "\(userAgent)")
    }

    @Test func websiteDataIsPersistent() async throws {
        let (webView, _) = try await appWebView()
        #expect(webView.configuration.websiteDataStore.isPersistent)
    }
}

/// Drives real `alert()`/`confirm()` calls through the app's `WKUIDelegate` in a test window whose root
/// controller captures the alert instead of showing it.
@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct JavaScriptDialogTests {
    private let model = WebShellModel(baseURL: AppConfig.baseURL)
    private let coordinator: WebView.Coordinator
    private let presenter = CapturingViewController()
    private let window: UIWindow

    init() async throws {
        coordinator = WebView.Coordinator(model: model)
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: scene)
        window.frame = scene.screen.bounds
        window.rootViewController = presenter
        model.webView.uiDelegate = coordinator
        model.webView.frame = presenter.view.bounds
        presenter.view.addSubview(model.webView)
        window.isHidden = false

        model.webView.loadHTMLString("<!doctype html><title>dialogs</title>", baseURL: nil)
        let loaded = await waitUntil(timeout: .seconds(10)) { [model] in
            (try? await model.webView.evaluateJavaScript("document.title") as? String) == "dialogs"
        }
        try #require(loaded)
    }

    private func answerConfirm(tapping title: String) async throws -> Bool? {
        let webView = model.webView
        let pending = Task {
            try await webView.callAsyncJavaScript("return confirm('Delete this workout?')", contentWorld: .page) as? Bool
        }

        let presented = await waitUntil(timeout: .seconds(10)) { [presenter] in !presenter.captured.isEmpty }
        try #require(presented, "confirm() never presented an alert")
        let alert = try #require(presenter.captured.first as? UIAlertController)
        #expect(alert.message == "Delete this workout?")
        #expect(alert.actions.map(\.title) == ["Cancel", "OK"])

        let action = try #require(alert.actions.first { $0.title == title })
        // UIAlertAction has no public way to fire its handler; the private "handler" key stands in for a tap.
        typealias Handler = @convention(block) (UIAlertAction) -> Void
        let block = try #require(action.value(forKey: "handler"))
        let handler = unsafeBitCast(block as AnyObject, to: Handler.self)
        handler(action)

        return try await pending.value
    }

    @Test func confirmOKReturnsTrue() async throws {
        #expect(try await answerConfirm(tapping: "OK") == true)
        window.isHidden = true
    }

    @Test func confirmCancelReturnsFalse() async throws {
        #expect(try await answerConfirm(tapping: "Cancel") == false)
        window.isHidden = true
    }

    @Test func dialogsWithoutAWindowResolveInsteadOfHanging() async throws {
        model.webView.removeFromSuperview()
        let result = try await model.webView.callAsyncJavaScript(
            "alert('hi'); return confirm('Delete this workout?')",
            contentWorld: .page
        )
        #expect(result as? Bool == false)
        #expect(presenter.captured.isEmpty)
        window.isHidden = true
    }
}
