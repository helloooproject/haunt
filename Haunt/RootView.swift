import SwiftUI

/// Shows the full-bleed startup art, then fades into the app.
struct RootView: View {
    @State private var showSplash = true
    var body: some View {
        ZStack {
            GhostCamView()
            if showSplash {
                SplashView().transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_900_000_000)
            withAnimation(.easeOut(duration: 0.7)) { showSplash = false }
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // The art already contains the "Haunt" wordmark.
            Image("LaunchGhost").resizable().scaledToFill().ignoresSafeArea()
        }
    }
}
