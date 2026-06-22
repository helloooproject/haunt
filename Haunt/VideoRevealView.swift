import SwiftUI
import AVKit

/// Plays the ghost-fade video in-app (the aha moment) on a loop, with share. Auto-plays on open.
struct VideoRevealView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var showShare = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                if let player {
                    VideoPlayer(player: player)
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal)
                }
                Spacer(minLength: 0)
                HStack(spacing: 14) {
                    Button { player?.seek(to: .zero); player?.play(); Haptics.tap() } label: {
                        Label("REPLAY", systemImage: "arrow.counterclockwise").revealBtn(.white.opacity(0.12), .white)
                    }
                    Button { showShare = true } label: {
                        Label("SHARE", systemImage: "square.and.arrow.up").revealBtn(.white, .black)
                    }
                }.padding(.horizontal)
                Button("Done") { dismiss() }.font(.footnote).foregroundStyle(.white.opacity(0.4)).padding(.bottom, 6)
            }.padding(.vertical)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShare) { ShareSheet(items: [url]) }
        .onAppear {
            let p = AVPlayer(url: url)
            player = p
            p.actionAtItemEnd = .none
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main) { _ in
                p.seek(to: .zero); p.play()   // loop
            }
            p.play()
        }
        .onDisappear { player?.pause() }
    }
}

private extension Label where Title == Text, Icon == Image {
    func revealBtn(_ bg: Color, _ fg: Color) -> some View {
        self.font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(1.5)
            .foregroundStyle(fg).frame(maxWidth: .infinity).frame(height: 52)
            .background(bg, in: RoundedRectangle(cornerRadius: 14))
    }
}
