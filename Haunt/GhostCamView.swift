import SwiftUI
import PhotosUI

/// The whole MVP loop: pick/take a photo → "scanning" → ghost render → share, with paywall gate.
struct GhostCamView: View {
    @StateObject private var engine = GhostEngine()
    @State private var pickerItem: PhotosPickerItem?
    @State private var sourcePhoto: UIImage?
    @State private var showShare = false
    @State private var showCamera = false
    @State private var showGallery = false
    @State private var revealed = false

    var body: some View {
        ZStack {
            // Haunted backdrop
            Color.black.ignoresSafeArea()
            Image("LaunchGhost").resizable().scaledToFill().ignoresSafeArea().opacity(0.16).blur(radius: 3)
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.9)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            content

            Vignette()
            GrainOverlay()
            cryptButton
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showGallery) { GalleryView() }
        .onChange(of: pickerItem) { _, item in loadPhoto(item) }
        .sheet(isPresented: $engine.showPaywall) { PaywallView(engine: engine) }
        .sheet(isPresented: $showShare) { if let img = engine.result { ShareSheet(items: [img]) } }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { img in
                sourcePhoto = img; engine.result = nil; engine.errorText = nil
                Analytics.track("photo_captured")
            }.ignoresSafeArea()
        }
    }

    // Correct pattern: ScrollView owns the content; header + bottom bar are safeAreaInsets
    // OF the scroll/content view, so content auto-insets and nothing hides behind them.
    @ViewBuilder private var content: some View {
        if engine.result != nil || sourcePhoto != nil {
            VStack {
                Spacer(minLength: 0)
                ZStack {
                    if let ghost = engine.result {
                        Image(uiImage: ghost).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18)).transition(.opacity)
                    } else if let src = sourcePhoto {
                        Image(uiImage: src).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay { if engine.isSummoning { ScanningOverlay() } }
                    }
                }.padding(.horizontal)
                Spacer(minLength: 0)
            }
            .safeAreaInset(edge: .top, spacing: 0) { pinnedHeader(compact: true) }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        } else {
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: cols, spacing: 10) {
                    reveal(surpriseCell, index: 0)
                    ForEach(Array(GhostStyle.library.enumerated()), id: \.element.id) { i, s in
                        reveal(ghostThumb(s), index: i + 1)
                    }
                }
                .padding(.horizontal).padding(.top, 4).padding(.bottom, 10)
            }
            .safeAreaInset(edge: .top, spacing: 0) { pinnedHeader(compact: false) }
            .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
            .onAppear { revealed = true }
        }
    }

    private func pinnedHeader(compact: Bool) -> some View {
        VStack(spacing: 4) {
            Text("Haunt").font(.custom("PicNic-Regular", size: compact ? 40 : 52)).foregroundStyle(.white).flicker()
            if !compact {
                Text("PUT A GHOST IN YOUR PHOTO")
                    .font(.system(.caption2, design: .monospaced)).tracking(2).foregroundStyle(.white.opacity(0.5))
                Text("STEP 1 — PICK YOUR GHOST")
                    .font(.system(.caption2, design: .monospaced)).tracking(2).foregroundStyle(.white.opacity(0.3)).padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6).padding(.bottom, 14)
        .background(LinearGradient(colors: [.black, .black, .black.opacity(0)], startPoint: .top, endPoint: .bottom))
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let err = engine.errorText {
                Text(err).font(.callout).foregroundStyle(.red.opacity(0.9)).multilineTextAlignment(.center).padding(.horizontal)
            }
            if engine.result == nil && sourcePhoto == nil {
                Text("STEP 2 — ADD YOUR PHOTO TO SUMMON \(selectedName)")
                    .font(.system(.caption2, design: .monospaced)).tracking(1).foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1).minimumScaleFactor(0.65).padding(.horizontal)
            }
            controls
            if !engine.unlocked {
                Text("\(engine.freeRemaining) FREE SUMMONS LEFT")
                    .font(.system(.caption2, design: .monospaced)).tracking(1.5).foregroundStyle(.white.opacity(0.35))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 14).padding(.bottom, 8)
        .background(LinearGradient(colors: [.black.opacity(0), .black, .black], startPoint: .top, endPoint: .bottom))
    }

    private var selectedName: String { (engine.selectedStyle?.name ?? "a random ghost").uppercased() }

    private var cryptButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { showGallery = true } label: {
                    Image(systemName: "square.grid.2x2.fill").font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.75)).padding(9).background(.ultraThinMaterial, in: Circle())
                }
            }.padding(.trailing, 14).padding(.top, 6)
            Spacer()
        }
    }

    @ViewBuilder private var controls: some View {
        if engine.result != nil {
            VStack(spacing: 12) {
                modeToggle   // flip vibe, then "Again" re-renders in it
                HStack(spacing: 14) {
                    actionButton("Share", "square.and.arrow.up") { showShare = true; Analytics.track("shared") }
                    actionButton("Again", "arrow.counterclockwise") { if let s = sourcePhoto { engine.summon(from: s) } }
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

    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    /// Staggered "materialize" reveal — each cell fades + rises in, delayed by index.
    private func reveal<V: View>(_ view: V, index: Int) -> some View {
        view
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 14)
            .animation(.easeOut(duration: 0.45).delay(Double(index) * 0.035), value: revealed)
    }

    private var surpriseCell: some View {
        let sel = engine.selectedStyle == nil
        return Button { engine.selectedStyle = nil } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.06))
                VStack(spacing: 6) {
                    Image(systemName: "dice.fill").font(.title2)
                    Text("SURPRISE\nME").font(.system(.caption2, design: .monospaced)).tracking(1).multilineTextAlignment(.center)
                }.foregroundStyle(.white.opacity(0.85))
            }
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: sel ? 2.5 : 0))
        }
    }

    private func ghostThumb(_ s: GhostStyle) -> some View {
        let sel = engine.selectedStyle?.id == s.id
        return Button { engine.selectedStyle = s } label: {
            ZStack(alignment: .bottomLeading) {
                if let img = s.referenceImage {
                    Image(uiImage: img).resizable().scaledToFill()
                } else { Color.white.opacity(0.06) }
                LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                Text(s.name.uppercased()).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white).padding(6)
            }
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white, lineWidth: sel ? 2.5 : 0))
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 8) {
            modeChip("KEEP MY ROOM", on: !engine.cinematic) { engine.cinematic = false }
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
