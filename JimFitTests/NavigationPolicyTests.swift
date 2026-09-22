import Foundation
import Testing
@testable import JimFit

struct NavigationPolicyTests {
    let policy = NavigationPolicy(baseURL: URL(string: "https://jimfit.app")!)

    private func decide(_ string: String, mainFrame: Bool = true) -> NavigationDecision {
        policy.decide(url: URL(string: string), isMainFrame: mainFrame)
    }

    @Test(arguments: [
        "https://jimfit.app",
        "https://jimfit.app/",
        "https://jimfit.app/privacy.html?x=1#top",
        "https://www.jimfit.app/",
        "https://JimFit.App/",
    ])
    func appHostsStayInApp(url: String) {
        #expect(decide(url) == .allow)
    }

    @Test(arguments: [
        "https://challenges.cloudflare.com/cdn-cgi/challenge-platform/turnstile",
        "https://example.com/",
        "http://example.com/",
        "mailto:support@jimfit.app",
        "about:blank",
    ])
    func subframesAreNeverIntercepted(url: String) {
        #expect(decide(url, mainFrame: false) == .allow)
    }

    @Test(arguments: [
        "https://example.com/",
        "https://challenges.cloudflare.com/",
        "https://wa.me/96100000000",
        "https://jimfit.app.evil.com/",
        "https://notjimfit.app/",
        "https://api.jimfit.app/",
    ])
    func externalHttpsOpensExternally(url: String) {
        #expect(decide(url) == .openExternally)
    }

    @Test(arguments: [
        "mailto:support@jimfit.app?subject=Help",
        "tel:+96100000000",
        "sms:+96100000000",
        "whatsapp://send?phone=96100000000",
        "itms-apps://apps.apple.com/app/id1",
    ])
    func otherSchemesOpenExternally(url: String) {
        #expect(decide(url) == .openExternally)
    }

    @Test(arguments: ["http://jimfit.app/", "http://www.jimfit.app/"])
    func plainHttpJimFitIsNotInApp(url: String) {
        #expect(decide(url) == .openExternally)
    }

    @Test func blankAndBlobStayInApp() {
        #expect(decide("about:blank") == .allow)
        #expect(decide("blob:https://jimfit.app/1234") == .allow)
    }

    @Test(arguments: ["file:///etc/hosts", "data:text/html,hi", "javascript:alert(1)"])
    func unsafeMainFrameSchemesAreCancelled(url: String) {
        #expect(decide(url) == .cancel)
    }

    @Test func missingURLIsCancelled() {
        #expect(policy.decide(url: nil, isMainFrame: true) == .cancel)
    }

    @Test func wwwBaseURLCoversBareHost() {
        let www = NavigationPolicy(baseURL: URL(string: "https://www.jimfit.app")!)
        #expect(www.decide(url: URL(string: "https://jimfit.app/"), isMainFrame: true) == .allow)
    }

    @Test func microphoneOriginIsJimFitHttpsOnly() {
        #expect(policy.isAppOrigin(scheme: "https", host: "jimfit.app"))
        #expect(policy.isAppOrigin(scheme: "https", host: "www.jimfit.app"))
        #expect(!policy.isAppOrigin(scheme: "http", host: "jimfit.app"))
        #expect(!policy.isAppOrigin(scheme: "https", host: "challenges.cloudflare.com"))
    }

    @Test func cancelledAndPolicyInterruptedLoadsAreNotErrors() {
        #expect(WebShellModel.isIgnorable(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
        #expect(WebShellModel.isIgnorable(NSError(domain: "WebKitErrorDomain", code: 102)))
        #expect(!WebShellModel.isIgnorable(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)))
    }
}
