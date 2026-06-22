import SwiftUI
import PhotosUI

/// The whole MVP loop: pick/take a photo → "scanning" → ghost render → share, with paywall gate.
struct GhostCamView: View {
    @StateObject private var engine = GhostEngine()
    @ObservedObject private var credits = CreditStore.shared
    @State private var pickerItem: PhotosPickerItem?
    @State private var sourcePhoto: UIImage?
    @State private var showShare = false
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var carouselIndex = 0
    @State private var flash = false
    @State private var makingVideo = false
    @State private var videoURL: URL?
    @State private var showVideoShare = false

    private func makeGhostVideo() {
        guard let src = sourcePhoto, let result = engine.result else { return }
        makingVideo = true
        Analytics.track("ghost_video_started")
        Task {
            let url = await GhostVideo.makeFade(original: src, haunted: result)
            makingVideo = false
            if let url { videoURL = url; showVideoShare = true; Analytics.track("ghost_video_made") }
            else { engine.errorText = "Couldn't make the video — try again."; Analytics.track("ghost_video_failed") }
        }
    }

    var body: some View {
        content
            .background { backdrop }
            .overlay { Vignette() }
            .overlay { GrainOverlay() }
            .overlay { flashLayer }
            .overlay(alignment: .topTrailing) { cryptButton }
            .onChange(of: engine.result) { _, r in onResult(r) }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $showGallery) { GalleryView() }
            .onChange(of: pickerItem) { _, item in loadPhoto(item) }
            .sheet(isPresented: $engine.showPaywall) { PaywallView() }
            .sheet(isPresented: $showShare) { if let img = engine.result { ShareSheet(items: [ShareCard.brand(img)]) } }
            .sheet(isPresented: $showVideoShare) { if let v = videoURL { ShareSheet(items: [v]) } }
            .fullScreenCover(isPresented: $showCamera) { cameraCover }
    }

    // Background in .background (ignoring safe area) so `content` keeps its real safe area —
    // that's what makes safeAreaInset land below the status bar / above the home indicator.
    private var backdrop: some View {
        ZStack {
            Color.black
            Image("LaunchGhost").resizable().scaledToFill().opacity(0.16).blur(radius: 3)
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    private var flashLayer: some View {
        Color.white.opacity(flash ? 0.92 : 0).ignoresSafeArea().allowsHitTesting(false)
    }

    private var cryptButton: some View {
        Button { showGallery = true } label: {
            Image(systemName: "square.grid.2x2.fill").font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.75)).padding(9).background(.ultraThinMaterial, in: Circle())
        }
        .padding(.trailing, 14).padding(.top, 4)
    }

    private var cameraCover: some View {
        CameraPicker { img in
            sourcePhoto = img; engine.result = nil; engine.errorText = nil
            Analytics.track("photo_captured")
        }.ignoresSafeArea()
    }

    /// The gotcha: flash + haptic the instant a ghost lands.
    private func onResult(_ r: UIImage?) {
        guard r != nil else { return }
        Haptics.gotcha()
        flash = true
        withAnimation(.easeOut(duration: 0.45)) { flash = false }
    }

    // Correct pattern: ScrollView owns the content; header + bottom bar are safeAreaInsets
    // OF the scroll/content view, so content auto-insets and nothing hides behind them.
    @ViewBuilder private var content: some View {
        // Result, or mid-summon: show the photo/result big. Otherwise the carousel is always the picker
        // (so "Again" returns here to pick a different ghost on the same photo).
        if engine.result != nil || (engine.isSummoning && sourcePhoto != nil) {
            VStack {
                Spacer(minLength: 0)
                ZStack {
                    if let ghost = engine.result, let src = sourcePhoto {
                        BeforeAfterView(before: src, after: ghost).transition(.opacity)
                    } else if let ghost = engine.result {
                        Image(uiImage: ghost).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18)).transition(.opacity)
                    } else if let src = sourcePhoto {
                        Image(uiImage: src).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay { if engine.isSummoning { ScanningOverlay() } }
                    }
                }.padding(.horizontal)
                if engine.result != nil, let name = engine.selectedStyle?.name {
                    Text(name.uppercased())
                        .font(.system(.caption, design: .monospaced).weight(.semibold)).tracking(3)
                        .foregroundStyle(.white.opacity(0.6)).padding(.top, 12)
                }
                Spacer(minLength: 0)
            }
            .safeAreaInset(edge: .top, spacing: 0) { pinnedHeader(compact: true) }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        } else {
            // Content-first: only ghost posters. "Surprise me" is a shuffle action (below), never a card.
            TabView(selection: $carouselIndex) {
                ForEach(Array(GhostStyle.library.enumerated()), id: \.element.id) { i, s in
                    ghostPoster(s).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .safeAreaInset(edge: .top, spacing: 0) { pinnedHeader(compact: false) }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .onChange(of: carouselIndex) { _, idx in
                engine.selectedStyle = GhostStyle.library[idx]
            }
            .onAppear { engine.selectedStyle = GhostStyle.library[carouselIndex] }
        }
    }

    /// Ghost poster as a centered, clearly-inset card (aspect-fit so it never touches the edges).
    private func ghostPoster(_ s: GhostStyle) -> some View {
        VStack {
            Spacer(minLength: 0)
            ZStack(alignment: .bottom) {
                if let img = s.referenceImage {
                    Image(uiImage: img).resizable().scaledToFill()
                } else { Color.white.opacity(0.06) }
                LinearGradient(colors: [.clear, .black.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                Text(s.name.uppercased())
                    .font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(3)
                    .foregroundStyle(.white).padding(.bottom, 16)
            }
            .aspectRatio(3.0/4.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.15), lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 22, y: 12)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 52)   // clear margins — card floats, never touches edges
    }

    private func pinnedHeader(compact: Bool) -> some View {
        VStack(spacing: 4) {
            Text("Haunt").font(.custom("PicNic-Regular", size: compact ? 38 : 46)).foregroundStyle(.white).flicker()
            if !compact {
                Text("PICK A GHOST · ADD YOUR PHOTO")
                    .font(.system(.caption2, design: .monospaced)).tracking(2).foregroundStyle(.white.opacity(0.4)).padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4).padding(.bottom, 12)
        .background(LinearGradient(colors: [.black, .black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let err = engine.errorText {
                Text(err).font(.callout).foregroundStyle(.red.opacity(0.9)).multilineTextAlignment(.center).padding(.horizontal)
            }
            controls
            Text("\(credits.balance) CREDITS")
                .font(.system(.caption2, design: .monospaced)).tracking(1.5).foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14).padding(.bottom, 8)
        .background(LinearGradient(colors: [.black.opacity(0), .black, .black], startPoint: .top, endPoint: .bottom))
    }

    private var selectedName: String { (engine.selectedStyle?.name ?? "a random ghost").uppercased() }


    @ViewBuilder private var controls: some View {
        if engine.result != nil {
            VStack(spacing: 12) {
                // Ghost-fade video — Realistic only (room is preserved, so only the ghost fades in).
                if !engine.cinematic, sourcePhoto != nil {
                    Button { makeGhostVideo() } label: {
                        Label(makingVideo ? "MAKING VIDEO…" : "GHOST VIDEO", systemImage: "play.rectangle.fill")
                            .font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(1.5)
                            .foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 50)
                            .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    }.disabled(makingVideo).padding(.horizontal)
                }
                HStack(spacing: 14) {
                    actionButton("Share", "square.and.arrow.up") { showShare = true; Analytics.track("shared") }
                    actionButton("Change ghost", "wand.and.stars") { withAnimation { engine.result = nil } }
                    actionButton("New photo", "photo.on.rectangle") { reset() }
                }.padding(.horizontal)
            }
        } else if sourcePhoto != nil {
            VStack(spacing: 14) {
                modeToggle
                primaryButton(engine.isSummoning ? "SUMMONING…" : "SUMMON") {
                    if let s = sourcePhoto { engine.summon(from: s) }
                }.disabled(engine.isSummoning)
            }
        } else {
            // One compact row: camera icon + primary "Choose a photo" — keeps CTAs above the home indicator.
            HStack(spacing: 12) {
                if CameraPicker.isAvailable {
                    Button { showCamera = true } label: {
                        Image(systemName: "camera.fill").font(.headline).foregroundStyle(.black)
                            .frame(width: 58, height: 54)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("CHOOSE A PHOTO", systemImage: "photo")
                        .font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(2)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal)
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 8) {
            modeChip("REALISTIC", on: !engine.cinematic) { engine.cinematic = false }
            modeChip("CINEMATIC", on: engine.cinematic) { engine.cinematic = true }
        }
    }
    private func modeChip(_ t: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(t).font(.system(.caption2, design: .monospaced)).tracking(1).foregroundStyle(on ? .black : .white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(on ? AnyShapeStyle(.white) : AnyShapeStyle(.white.opacity(0.12)), in: Capsule())
        }
    }

    private func actionButton(_ t: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) { Image(systemName: icon).font(.title3); Text(t.uppercased()).font(.system(.caption2, design: .monospaced)).tracking(1) }
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }
    private func primaryButton(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(t).primaryLabelStyle() }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                sourcePhoto = img; engine.result = nil; engine.errorText = nil
                Analytics.track("photo_chosen")
            }
        }
    }
    private func reset() { sourcePhoto = nil; engine.result = nil; engine.errorText = nil; pickerItem = nil }
}

private struct ScanningOverlay: View {
    @State private var sweep = false
    var body: some View {
        RoundedRectangle(cornerRadius: 18).fill(.black.opacity(0.35))
            .overlay {
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text("SCANNING FOR SPIRITS").font(.system(.caption, design: .monospaced)).tracking(2).foregroundStyle(.white.opacity(0.85))
                }
            }
    }
}

private struct EmptyState: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.15), style: .init(lineWidth: 1, dash: [6]))
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder").font(.system(size: 44)).foregroundStyle(.white.opacity(0.3))
                    Text("PICK A PHOTO OF A ROOM\nWE'LL FIND WHAT'S ALREADY THERE")
                        .font(.system(.caption, design: .monospaced)).tracking(1.5)
                        .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.4)).lineSpacing(4)
                }
            }
    }
}

private extension View {
    func primaryLabelStyle() -> some View {
        self.font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(2)
            .foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
    }
}

/// UIKit share sheet bridge.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { .init(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
