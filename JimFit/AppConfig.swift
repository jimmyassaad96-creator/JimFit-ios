import Foundation

enum AppConfig {
    static let baseURL: URL = {
        var value = Bundle.main.object(forInfoDictionaryKey: "JimFitBaseURL") as? String
        #if DEBUG
        // UI tests launch with `-JimFitBaseURL https://jimfit.invalid` to reach the error screen; the
        // launch argument lands in UserDefaults' argument domain and is never persisted.
        if let override = UserDefaults.standard.string(forKey: "JimFitBaseURL") { value = override }
        #endif
        guard let value, let url = URL(string: value), url.scheme == "https", url.host != nil
        else { fatalError("JimFitBaseURL must be an https URL") }
        return url
    }()

    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
}
