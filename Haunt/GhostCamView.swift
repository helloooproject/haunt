import SwiftUI
import PhotosUI

/// The whole MVP loop: pick/take a photo → "scanning" → ghost render → share, with paywall gate.
struct GhostCamView: View {
    @StateObject private var engine = GhostEngine()
    @State private var pickerItem: PhotosPickerItem?
    @State private var sourcePhoto: UIImage?
    @State private var showShare = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                header

                ZStack {
                    // Result > source > empty state
                    if let ghost = engine.result {
                        Image(uiImage: ghost).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .transition(.opacity)
                    } else if let src = sourcePhoto {
                        Image(uiImage: src).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay { if engine.isSummoning { ScanningOverlay() } }
                    } else {
                        EmptyState()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 460)
                .padding(.horizontal)

                if let err = engine.errorText {
                    Text(err).font(.callout).foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center).padding(.horizontal)
                }

                controls
                Spacer()
                if !engine.hasPro {
                    Text("\(engine.freeRemaining) free summons left")
                        .font(.footnote).foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.top, 12)
        }
        .preferredColorScheme(.dark)
        .onChange(of: pickerItem) { _, item in loadPhoto(item) }
        .sheet(isPresented: $engine.showPaywall) { PaywallView(engine: engine) }
        .sheet(isPresented: $showShare) { if let img = engine.result { ShareSheet(items: [img]) } }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("HAUNT").font(.system(size: 28, weight: .heavy, design: .serif)).tracking(8).foregroundStyle(.white)
            Text("summon the dead into your photos").font(.caption).foregroundStyle(.white.opacity(0.45))
        }
    }

    @ViewBuilder private var controls: some View {
        if engine.result != nil {
            HStack(spacing: 14) {
                actionButton("Share", "square.and.arrow.up") { showShare = true; Analytics.track("shared") }
                actionButton("Again", "arrow.counterclockwise") { if let s = sourcePhoto { engine.summon(from: s) } }
                actionButton("New photo", "photo.on.rectangle") { reset() }
            }.padding(.horizontal)
        } else if sourcePhoto != nil {
            primaryButton(engine.isSummoning ? "Summoning…" : "👻 Summon ghost") {
                if let s = sourcePhoto { engine.summon(from: s) }
            }.disabled(engine.isSummoning)
        } else {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose a photo", systemImage: "photo").primaryLabelStyle()
            }
        }
    }

    private func actionButton(_ t: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) { Image(systemName: icon).font(.title3); Text(t).font(.caption) }
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
                    Text("scanning for spirits…").font(.caption).foregroundStyle(.white.opacity(0.8))
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
                    Text("Pick a photo of a room.\nWe'll find what's already there.").font(.callout)
                        .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.4))
                }
            }
    }
}

private extension View {
    func primaryLabelStyle() -> some View {
        self.font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16)).padding(.horizontal)
    }
}

/// UIKit share sheet bridge.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { .init(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
