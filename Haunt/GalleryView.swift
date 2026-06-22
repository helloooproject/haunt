import SwiftUI

/// "The Crypt" — saved summons with the ghost used on each.
struct GalleryView: View {
    @ObservedObject var store = SummonStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selected: SavedSummon?
    @State private var newestFirst = true
    @State private var makingVideo = false
    @State private var videoURL: URL?
    @State private var showVideoShare = false
    @State private var showFeedback = false
    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var displayed: [SavedSummon] {
        store.items.sorted { newestFirst ? $0.date > $1.date : $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if store.items.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "moon.stars").font(.system(size: 40)).foregroundStyle(.white.opacity(0.3))
                        Text("NO HAUNTS YET").font(.system(.caption, design: .monospaced)).tracking(2).foregroundStyle(.white.opacity(0.4))
                        Text("Your summoned ghosts are saved here.").font(.system(.caption2, design: .monospaced)).foregroundStyle(.white.opacity(0.25))
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: cols, spacing: 14) {
                            ForEach(displayed) { s in cell(s).onTapGesture { selected = s } }
                        }
                        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 28)
                    }
                }
            }
            .navigationTitle("My Haunts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { newestFirst.toggle() } label: {
                        Label(newestFirst ? "Newest" : "Oldest", systemImage: "arrow.up.arrow.down").foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showFeedback = true } label: {
                        Image(systemName: "bubble.left").foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(.white) }
            }
            .preferredColorScheme(.dark)
            .sheet(item: $selected) { s in detail(s) }
            .sheet(isPresented: $showFeedback) { FeedbackView() }
        }
    }

    private func cell(_ s: SavedSummon) -> some View {
        // Color.clear sets the cell size; image fills via overlay + clipped (no overflow).
        Color.white.opacity(0.06)
            .aspectRatio(0.8, contentMode: .fit)
            .overlay {
                if let img = store.image(for: s) {
                    Image(uiImage: img).resizable().scaledToFill()
                }
            }
            .overlay(alignment: .bottomLeading) {
                LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                    .overlay(alignment: .bottomLeading) {
                        Text(s.preset.uppercased())
                            .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white).padding(8)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func detail(_ s: SavedSummon) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer(minLength: 0)
                if let img = store.image(for: s), let orig = store.originalImage(for: s) {
                    BeforeAfterView(before: orig, after: img)   // drag to compare original ↔ haunted
                } else if let img = store.image(for: s) {
                    Image(uiImage: img).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Text("\(s.preset.uppercased())  ·  \(s.mode.uppercased())")
                    .font(.system(.caption2, design: .monospaced)).tracking(1).foregroundStyle(.white.opacity(0.5))
                Spacer(minLength: 0)

                // Animate any past Realistic haunt — special feature = a reason to come back.
                if s.mode == "Realistic", store.originalImage(for: s) != nil {
                    Button { makeVideo(s) } label: {
                        Label(makingVideo ? "SUMMONING…" : "GHOST VIDEO", systemImage: "play.rectangle.fill")
                            .font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(1.5)
                            .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    }.disabled(makingVideo).padding(.horizontal)
                }

                HStack(spacing: 14) {
                    if let img = store.image(for: s) {
                        let branded = Image(uiImage: ShareCard.brand(img))
                        ShareLink(item: branded, preview: SharePreview("Haunt", image: branded)) {
                            Label("SHARE", systemImage: "square.and.arrow.up").galleryBtn()
                        }
                    }
                    Button(role: .destructive) { store.delete(s); selected = nil } label: {
                        Label("DELETE", systemImage: "trash").galleryBtn()
                    }
                }.padding(.horizontal)
            }.padding()
        }
        .overlay(alignment: .topTrailing) {
            Button { selected = nil } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .padding(10).background(.ultraThinMaterial, in: Circle())
            }.padding(.trailing, 16).padding(.top, 12)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showVideoShare) { if let v = videoURL { VideoRevealView(url: v) } }
    }

    private func makeVideo(_ s: SavedSummon) {
        guard let haunted = store.image(for: s), let orig = store.originalImage(for: s) else { return }
        Haptics.gotcha()
        makingVideo = true
        Analytics.track("ghost_video_started", ["from": "crypt"])
        Task {
            let url = await GhostVideo.makeFade(original: orig, haunted: haunted)
            makingVideo = false
            if let url { videoURL = url; showVideoShare = true; Analytics.track("ghost_video_made", ["from": "crypt"]) }
        }
    }
}

private extension View {
    func galleryBtn() -> some View {
        self.font(.system(.caption, design: .monospaced)).tracking(1).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}
