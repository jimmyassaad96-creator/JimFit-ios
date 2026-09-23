# JimFit iOS — notes for the next agent

A native SwiftUI shell around the live JimFit web app. It loads
`https://jimfit.app` in a `WKWebView` and bundles none of the web app, so every
web deploy reaches iOS users with no store release. The Android twin is
`jimmyassaad96-creator/JimFit-android`; both follow the same behaviour contract,
so a behaviour change here usually needs the matching change there.

The web app lives in `jimmyassaad96-creator/JimFit`, a single-file React app
(`index.html`) plus a Supabase backend. Nothing in this repo can change what the
page does, only how the phone hosts it.

## If you are checking this repo for Jimmy

Jimmy does not work from a terminal. What he wants to know is: does the app open
JimFit and work.

```bash
xcodebuild -project JimFit.xcodeproj -scheme JimFit \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Expected: `** TEST SUCCEEDED **`, 43 tests: 38 in `JimFitTests`, 5 in
`JimFitUITests`. Both targets need internet because they hit the live site. Pick
any available iPhone from `xcrun simctl list devices available` if iPhone 17 is
missing. Report failures verbatim rather than fixing them.

## Hard rules

- **Never push, never commit unless asked.** Said pushes himself; a hook blocks
  `git push`.
- **No third-party dependencies.** No SPM packages.
- **The project uses file-system synchronized groups** (`objectVersion 77`). New
  files under `JimFit/`, `JimFitTests/` or `JimFitUITests/` are picked up
  automatically. Don't add file references to `project.pbxproj` by hand.
- Swift 6, MainActor default isolation. `NavigationPolicy` is `nonisolated` so
  tests can call it directly.

## Layout

```
JimFitApp.swift            App entry; creates WebShellModel
AppConfig.swift            base URL from Info.plist key JimFitBaseURL
                           (DEBUG only: -JimFitBaseURL launch-arg override, used by UI tests)
Web/NavigationPolicy.swift pure: allow / open externally / cancel, per URL.
                           All the routing rules live here.
Web/WebShellModel.swift    @Observable; owns the WKWebView, progress and error state
Web/WebView.swift          UIViewRepresentable + Coordinator: navigation delegate,
                           window.open, microphone permission, alert/confirm
Web/WebShellView.swift     SwiftUI root: web view, progress bar, error overlay
```

The user agent gets `JimFitiOS/<CFBundleShortVersionString>` appended so the
web app can tell it is in the shell.

## Bugs already found here, so you don't reintroduce them

- **Do not create the `WKWebView` in `App.init` or the model's `init`.** Built
  before UIKit has a scene, it crashes with SIGABRT inside UIKit's gesture
  handling on the first tap (reproduced on iOS 18.5, 26.4 and 26.5, even loading
  example.com). It is a `lazy var` first touched in `makeUIView`. The
  "Get started" UI test catches a regression.
- **JS `alert()`/`confirm()` must be presented by the app.** WKWebView drops
  them silently otherwise, so `confirm()` always returns false and the web app's
  22 confirm-first actions never go through. `WebView.swift` presents them with
  `UIAlertController`, and a dialog with no window to show it still resolves
  instead of hanging.
- **Subframes are never intercepted.** Cloudflare Turnstile runs in a
  `challenges.cloudflare.com` iframe; routing it outside the app would break login.

## Behaviour that looks like a bug but is the web app

- **Offline after a previous visit shows a blank page, not the error view.**
  `sw.js` serves the cached HTML but React loads from a CDN and isn't cached.
  Fix it in the web app's service worker.
- **There is no in-app history on the welcome and login-choice screens.** The
  web app has no routing, so swipe-back has nothing to go back to.

## Testing notes

- The JS dialog tests trigger `UIAlertAction` handlers through the private
  `"handler"` key, because there is no public way to press an alert button. This is
  test-only code and never ships.
- The UI target is set non-parallel in the scheme, and the unit target is
  parallel. That is why the unit tests run on "Clone 1 of iPhone 17".
- Live site text can differ from Jimmy's local `index.html` (for example, the live site
  says "I'm a Member" where older `main` said "I'm a Client"). "Privacy Policy"
  is a button that opens a modal, not a link. Assert against the live site.

## Blocked on decisions, not code

- **Signing:** no development team is set. Jimmy's Apple Developer account is
  needed before running on a device or archiving.
- **App Review:** guideline 4.2 rejects apps that only wrap a website, and the
  web app sells subscriptions and plans through Whish Money. Digital
  subscriptions in an iOS app generally must use Apple in-app purchase
  (3.1.1). Settle this before submitting.

## Next step for Jimmy: publishing on the App Store

The app builds and passes its tests; what's left is store work that only Jimmy
can do with his Apple account. Walk him through it in this order:

1. **Settle payments first** (see above). It is the likeliest rejection and can
   change what the web app shows inside iOS.
2. **Apple Developer Program** ($99/year). Then in Xcode → Signing &
   Capabilities, set his Team for the `JimFit` target.
3. **App Store Connect:** create the app with bundle ID `app.jimfit`. The ID
   can never change after the first upload.
4. **Store listing:** screenshots for 6.9" iPhone and 13" iPad (the app
   supports iPad), description, keywords, support URL, privacy policy URL
   `https://jimfit.app/privacy.html`.
5. **App Privacy labels:** account email, name, photos, voice audio, payment
   info. In-app account deletion is required for apps with sign-up; the web
   app already has "Delete my account".
6. **Review notes:** give Apple a working demo login (member and trainer),
   since everything sits behind sign-in.
7. **Build:** Xcode → Product → Archive → Distribute → App Store Connect →
   test via **TestFlight** → Submit for Review. Bump the build number for
   every upload.

## Not done

Push notifications (APNs plus a native bridge), universal links
(`apple-app-site-association` plus Associated Domains), and a real-device test
of login, Turnstile, camera, photo picker and microphone.
