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

    var body: some View {
        ZStack {
            // Haunted backdrop: the launch art, dimmed, so the home feels possessed not empty.
            Color.black.ignoresSafeArea()
            Image("LaunchGhost").resizable().scaledToFill().ignoresSafeArea()
                .opacity(0.22).blur(radius: 2)
            LinearGradient(colors: [.black.opacity(0.5), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 12) {
                header.padding(.top, 14)

                // Flexible middle: image (or grid) fills remaining space so controls always sit at the bottom.
                Group {
                    if engine.result != nil || sourcePhoto != nil {
                        ZStack {
                            if let ghost = engine.result {
                                Image(uiImage: ghost).resizable().scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .transition(.opacity)
                            } else if let src = sourcePhoto {
                                Image(uiImage: src).resizable().scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .overlay { if engine.isSummoning { ScanningOverlay() } }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        ghostGrid   // PICK YOUR GHOST — fills the home
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let err = engine.errorText {
                    Text(err).font(.callout).foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center).padding(.horizontal)
                }

                controls
                if !engine.unlocked {
                    Text("\(engine.freeRemaining) FREE SUMMONS LEFT")
                        .font(.system(.caption2, design: .monospaced)).tracking(1.5).foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.bottom, 10)

            // Crypt (gallery) button, top-right
            VStack {
                HStack {
                    Spacer()
                    Button { showGallery = true } label: {
                        Image(systemName: "square.grid.2x2.fill").font(.system(size: 17))
                            .foregroundStyle(.white.opacity(0.7)).padding(10)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                }.padding(.trailing, 16).padding(.top, 8)
                Spacer()
            }
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

    private var header: some View {
        VStack(spacing: 4) {
            Text("Haunt").font(.custom("PicNic-Regular", size: 64)).foregroundStyle(.white)
            Text("SUMMON THE DEAD INTO YOUR PHOTOS")
                .font(.system(.caption, design: .monospaced)).tracking(2)
                .foregroundStyle(.white.opacity(0.4))
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
            VStack(spacing: 12) {
                if CameraPicker.isAvailable {
                    Button { showCamera = true } label: {
                        Label("TAKE A PHOTO", systemImage: "camera.fill").primaryLabelStyle()
                    }
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("CHOOSE A PHOTO", systemImage: "photo")
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold)).tracking(1)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                }
            }
        }
    }

    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var ghostGrid: some View {
        VStack(spacing: 12) {
            Text("PICK YOUR GHOST").font(.system(.caption, design: .monospaced)).tracking(3).foregroundStyle(.white.opacity(0.5))
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: cols, spacing: 10) {
                    surpriseCell
                    ForEach(GhostStyle.library) { s in ghostThumb(s) }
                }.padding(.horizontal)
            }
        }
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
