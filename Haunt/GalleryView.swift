import SwiftUI

/// "The Crypt" — saved summons with the ghost used on each.
struct GalleryView: View {
    @ObservedObject var store = SummonStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selected: SavedSummon?
    @State private var newestFirst = true
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
                        Text("THE CRYPT IS EMPTY").font(.system(.caption, design: .monospaced)).tracking(2).foregroundStyle(.white.opacity(0.4))
                        Text("Summoned ghosts are saved here.").font(.system(.caption2, design: .monospaced)).foregroundStyle(.white.opacity(0.25))
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: cols, spacing: 10) {
                            ForEach(displayed) { s in cell(s).onTapGesture { selected = s } }
                        }.padding()
                    }
                }
            }
            .navigationTitle("The Crypt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { newestFirst.toggle() } label: {
                        Label(newestFirst ? "Newest" : "Oldest", systemImage: "arrow.up.arrow.down").foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.foregroundStyle(.white) }
            }
            .preferredColorScheme(.dark)
            .sheet(item: $selected) { s in detail(s) }
        }
    }

    private func cell(_ s: SavedSummon) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let img = store.image(for: s) {
                Image(uiImage: img).resizable().scaledToFill()
            } else { Color.white.opacity(0.06) }
            LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
            Text(s.preset.uppercased())
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.white).padding(8)
        }
        .aspectRatio(0.8, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func detail(_ s: SavedSummon) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                if let img = store.image(for: s), let orig = store.originalImage(for: s) {
                    BeforeAfterView(before: orig, after: img)   // drag to compare original ↔ haunted
                } else if let img = store.image(for: s) {
                    Image(uiImage: img).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 16))
                }
                Text("\(s.preset.uppercased())  ·  \(s.mode.uppercased())")
                    .font(.system(.caption2, design: .monospaced)).tracking(1).foregroundStyle(.white.opacity(0.5))
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
        }.preferredColorScheme(.dark)
    }
}

private extension View {
    func galleryBtn() -> some View {
        self.font(.system(.caption, design: .monospaced)).tracking(1).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}
