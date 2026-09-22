import Foundation

nonisolated enum NavigationDecision: Equatable, Sendable {
    case allow
    case openExternally
    case cancel
}

nonisolated struct NavigationPolicy: Sendable {
    let appHosts: Set<String>

    init(baseURL: URL) {
        let host = (baseURL.host ?? "").lowercased()
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        appHosts = [bare, "www." + bare]
    }

    func decide(url: URL?, isMainFrame: Bool) -> NavigationDecision {
        // Turnstile renders in a challenges.cloudflare.com iframe; intercepting it breaks login.
        guard isMainFrame else { return .allow }
        guard let url, let scheme = url.scheme?.lowercased() else { return .cancel }

        switch scheme {
        case "https":
            return isAppHost(url.host) ? .allow : .openExternally
        case "http":
            return .openExternally
        case "about", "blob":
            return .allow
        case "file", "data", "javascript":
            return .cancel
        default:
            return .openExternally
        }
    }

    func isAppOrigin(scheme: String, host: String) -> Bool {
        scheme.lowercased() == "https" && isAppHost(host)
    }

    private func isAppHost(_ host: String?) -> Bool {
        guard let host else { return false }
        return appHosts.contains(host.lowercased())
    }
}
