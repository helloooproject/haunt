import Foundation
import SwiftUI

/// Summon credits. Each summon spends 1; failed summons are NOT charged.
/// Free starter grant hooks the user; packs (consumables) refill.
/// Credits model chosen because each summon has real API COGS (~$0.06).
@MainActor
final class CreditStore: ObservableObject {
    static let shared = CreditStore()
    @Published private(set) var balance: Int

    private let key = "haunt_credits"
    private let freeStart = 3
    private let d = UserDefaults.standard

    init() {
        if d.object(forKey: key) == nil { d.set(freeStart, forKey: key) }
        balance = d.integer(forKey: key)
    }

    var canSummon: Bool { balance > 0 }
    func spend() { guard balance > 0 else { return }; balance -= 1; d.set(balance, forKey: key) }
    func add(_ n: Int) { balance += n; d.set(balance, forKey: key) }
}

/// Credit packs sold as StoreKit consumables. IDs must match App Store Connect.
struct CreditPack: Identifiable {
    let id: String       // ASC product id
    let credits: Int
    static let all: [CreditPack] = [
        .init(id: "com.rci.haunt.credits25", credits: 25),
        .init(id: "com.rci.haunt.credits75", credits: 75),
        .init(id: "com.rci.haunt.credits200", credits: 200)
    ]
    static func credits(for productID: String) -> Int { all.first { $0.id == productID }?.credits ?? 0 }
}
