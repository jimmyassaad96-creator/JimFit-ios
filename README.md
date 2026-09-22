# JimFit for iOS

A native SwiftUI shell around the JimFit web app. It loads `https://jimfit.app` in a `WKWebView`; the web app itself is not bundled, so web deploys reach the app without a store release.

## Build and run

Requires Xcode 16 or newer (built with Xcode 26.6). No dependencies.

```bash
open JimFit.xcodeproj            # then Run on a simulator
```

The base URL is the `JimFitBaseURL` key in `JimFit/Info.plist`.

## Tests

```bash
xcodebuild -project JimFit.xcodeproj -scheme JimFit \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

This runs both targets. `JimFitTests` covers `NavigationPolicy`, the `alert`/`confirm` delegate, and, against the live jimfit.app, full-height layout (`100vh` equals the window), the user agent and the persistent data store. `JimFitUITests` drives the live site without logging in: welcome screen, login choice, privacy policy, rotation, and the offline screen (Debug builds accept `-JimFitBaseURL <url>` to point at an unreachable host). Both need network.

## Layout

- `JimFit/Web/NavigationPolicy.swift` decides, per URL, whether a navigation stays in the app, opens externally (other sites, `mailto:`, `tel:`, WhatsApp) or is cancelled. Subframes are never intercepted, so Cloudflare Turnstile works. Unit-tested in `JimFitTests/`.
- `JimFit/Web/WebShellModel.swift` owns the `WKWebView` and the loading/error state.
- `JimFit/Web/WebView.swift` is the SwiftUI bridge and WebKit delegate (navigation, `window.open`, microphone permission, `alert`/`confirm`).
- The user agent ends in `JimFitiOS/<version>` so the web app can detect the shell.

## Not done yet

- **Push notifications.** WKWebView in an app does not get the Web Push API; this needs APNs and a native bridge.
- **Universal links.** Password-reset and other emailed links open in Safari, not the app. Needs an `apple-app-site-association` file on jimfit.app and the Associated Domains entitlement.
- **Signing and App Store.** No development team is set. Pick one in Signing & Capabilities before running on a device or archiving.
- **App Review risk.** Apple guideline 4.2 rejects apps that are only a wrapped website, and the web app sells subscriptions and plans through Whish Money. Digital subscriptions sold inside an iOS app generally must use Apple in-app purchase (guideline 3.1.1). Settle the payment approach before submitting.
