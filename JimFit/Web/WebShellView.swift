import SwiftUI

struct WebShellView: View {
    let model: WebShellModel

    var body: some View {
        ZStack(alignment: .top) {
            Color("Background").ignoresSafeArea()

            // Container only, so SwiftUI still shrinks the web view above the keyboard.
            WebView(model: model)
                .ignoresSafeArea(.container)

            if model.isLoading && model.progress < 1 {
                ProgressView(value: model.progress)
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
                    .frame(height: 2)
                    .transition(.opacity)
            }

            if let message = model.loadError {
                LoadErrorView(message: message, retry: model.retry)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.isLoading)
    }
}

private struct LoadErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Can't reach JimFit")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("Background").ignoresSafeArea())
        .foregroundStyle(.white)
    }
}
