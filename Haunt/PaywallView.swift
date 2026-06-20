import SwiftUI
import StoreKit

/// One-time unlock paywall (no subscription — the audience won't sub to a toy).
/// TODO(cody): create a non-consumable IAP in App Store Connect and set productID below.
struct PaywallView: View {
    @ObservedObject var engine: GhostEngine
    @Environment(\.dismiss) private var dismiss
    @State private var products: [Product] = []
    @State private var buying = false

    private let productID = "com.rci.haunt.unlock"   // matches the ASC non-consumable

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 22) {
                Spacer()
                Text("👻").font(.system(size: 60))
                Text("Unlock unlimited summons").font(.title2.bold()).foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 10) {
                    perk("Summon ghosts into any photo")
                    perk("Save & share in full quality")
                    perk("One-time purchase — yours forever")
                }.padding(.horizontal, 40)
                Spacer()
                Button {
                    Task { await buy() }
                } label: {
                    Text(buying ? "…" : (products.first.map { "Unlock — \($0.displayPrice)" } ?? "Unlock"))
                        .font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }.padding(.horizontal).disabled(buying)
                Button("Restore Purchase") { Task { await restore() } }
                    .font(.footnote).foregroundStyle(.white.opacity(0.6))
                Button("Not now") { dismiss() }.font(.footnote).foregroundStyle(.white.opacity(0.35)).padding(.bottom)
            }
        }
        .task { await loadProducts() }
    }

    private func perk(_ t: String) -> some View {
        HStack(spacing: 10) { Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
            Text(t).foregroundStyle(.white.opacity(0.85)).font(.subheadline) }
    }

    private func loadProducts() async {
        products = (try? await Product.products(for: [productID])) ?? []
    }
    private func buy() async {
        guard let product = products.first else { return }
        buying = true; defer { buying = false }
        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result, case .verified = verification {
            engine.hasPro = true; Analytics.track("purchased", ["product": productID]); dismiss()
        }
    }
    private func restore() async {
        try? await AppStore.sync()
        for await ent in Transaction.currentEntitlements {
            if case .verified(let t) = ent, t.productID == productID { engine.hasPro = true; dismiss() }
        }
    }
}
