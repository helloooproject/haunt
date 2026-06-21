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

/// 3 full-bleed ghost photos carry the pitch — swipe through, then drop into the app.
struct OnboardingView: View {
    var done: () -> Void
    @State private var page = 0

    private struct Beat { let image: String; let title: String; let sub: String }
    private let beats = [
        Beat(image: "LaunchGhost", title: "PUT A REAL GHOST\nIN YOUR PHOTOS", sub: "AI drops a photoreal spirit into any photo you take."),
        Beat(image: "ghost_06",    title: "PICK YOUR\nHAUNTING",            sub: "Choose from a gallery of ghosts — or let fate decide."),
        Beat(image: "ghost_12",    title: "SHARE THE\nSCARE",               sub: "Send it to someone. Watch them flinch.")
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            TabView(selection: $page) {
                ForEach(beats.indices, id: \.self) { i in
                    Image(beats[i].image).resizable().scaledToFill().ignoresSafeArea().tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            LinearGradient(colors: [.clear, .black.opacity(0.55), .black], startPoint: .center, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 16) {
                Text(beats[page].title)
                    .font(.system(.title, design: .monospaced).weight(.bold)).tracking(2)
                    .multilineTextAlignment(.center).foregroundStyle(.white)
                Text(beats[page].sub)
                    .font(.system(.footnote, design: .monospaced)).tracking(0.5)
                    .foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
                    .frame(maxWidth: 300)

                dots.padding(.vertical, 6)

                Button {
                    Haptics.tap()
                    if page < beats.count - 1 { withAnimation { page += 1 } }
                    else { Analytics.track("onboarding_done"); done() }
                } label: {
                    Text(page < beats.count - 1 ? "NEXT" : "START HAUNTING")
                        .font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(2)
                        .foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 56)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 28).padding(.bottom, 36)
            .animation(.easeInOut, value: page)

            Vignette()
            GrainOverlay()
        }
        .preferredColorScheme(.dark)
        .overlay(alignment: .topTrailing) {
            if page < beats.count - 1 {
                Button("Skip") { Analytics.track("onboarding_skipped"); done() }
                    .font(.system(.footnote, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                    .padding(.trailing, 20).padding(.top, 8)
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(beats.indices, id: \.self) { i in
                Circle().fill(.white.opacity(i == page ? 1 : 0.3)).frame(width: 7, height: 7)
            }
        }
    }
}
