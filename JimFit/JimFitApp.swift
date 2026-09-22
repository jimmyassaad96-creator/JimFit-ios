import SwiftUI

@main
struct JimFitApp: App {
    @State private var model = WebShellModel(baseURL: AppConfig.baseURL)

    var body: some Scene {
        WindowGroup {
            WebShellView(model: model)
        }
    }
}
