import SwiftUI

/// First run → onboarding (leverages the hero ghost photo). After that → straight to the app.
/// No timed splash: the native launch screen already shows the art instantly on cold start.
struct RootView: View {
    @AppStorage("onboarded") private var onboarded = false
    var body: some View {
        if onboarded {
            GhostCamView()
        } else {
            OnboardingView { onboarded = true }
        }
    }
}

/// Full-bleed hero ghost as the onboarding canvas — sell the magic, then drop them in.
struct OnboardingView: View {
    var done: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            // The amazing photograph, full bleed
            Image("LaunchGhost").resizable().scaledToFill().ignoresSafeArea()
            LinearGradient(colors: [.clear, .black.opacity(0.5), .black], startPoint: .center, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("PUT A REAL GHOST\nIN YOUR PHOTOS")
                    .font(.system(.title2, design: .monospaced).weight(.bold)).tracking(2)
                    .multilineTextAlignment(.center).foregroundStyle(.white)
                Text("Pick a ghost → add your photo → share the scare.")
                    .font(.system(.caption, design: .monospaced)).tracking(1)
                    .foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)

                Button {
                    Haptics.tap(); Analytics.track("onboarding_done"); done()
                } label: {
                    Text("START HAUNTING")
                        .font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(2)
                        .foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 56)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }.padding(.top, 8)
            }
            .padding(.horizontal, 28).padding(.bottom, 40)
            .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 20)

            Vignette()
            GrainOverlay()
        }
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(.easeOut(duration: 0.8).delay(0.2)) { appear = true } }
    }
}
