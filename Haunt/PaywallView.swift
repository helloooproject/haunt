import SwiftUI
import StoreKit

/// Credit-pack store. Consumables — each summon costs 1 credit (real API COGS ~$0.06).
struct PaywallView: View {
    @ObservedObject var credits = CreditStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []
    @State private var buying: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Text("👻").font(.system(size: 56))
                Text(credits.balance > 0 ? "MORE SUMMONS" : "OUT OF SUMMONS").font(.system(.title2, design: .monospaced).weight(.bold)).tracking(2).foregroundStyle(.white)
                Text("\(credits.balance) credits left").font(.system(.caption, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                Spacer()

                ForEach(products.sorted { $0.price < $1.price }, id: \.id) { p in
                    Button { Task { await buy(p) } } label: {
                        HStack {
                            Text("\(CreditPack.credits(for: p.id)) SUMMONS")
                                .font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(1)
                            Spacer()
                            Text(buying == p.id ? "…" : p.displayPrice)
                                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        }
                        .foregroundStyle(.black).padding(.horizontal, 20).frame(height: 56)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(buying != nil).padding(.horizontal)
                }

                Button("Not now") { dismiss() }.font(.footnote).foregroundStyle(.white.opacity(0.35)).padding(.vertical, 4)

                HStack(spacing: 6) {
                    Link("Privacy", destination: URL(string: "https://rectanglecircle.co/privacy.html")!)
                    Text("·")
                    Link("Terms", destination: URL(string: "https://rectanglecircle.co/terms.html")!)
                    Text("·")
                    Text("Credits are consumable")
                }
                .font(.system(.caption2, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                .padding(.bottom, 10)
            }
        }
        .preferredColorScheme(.dark)
        .task { await load() }
    }

    private func load() async {
        products = (try? await Product.products(for: CreditPack.all.map(\.id))) ?? []
    }
    private func buy(_ product: Product) async {
        buying = product.id; defer { buying = nil }
        guard let result = try? await product.purchase() else { return }
        if case .success(let v) = result, case .verified(let t) = v {
            credits.add(CreditPack.credits(for: product.id))
            await t.finish()                       // consumables must be finished
            Analytics.track("purchased", ["pack": product.id, "credits": CreditPack.credits(for: product.id)])
            dismiss()
        }
    }
}
