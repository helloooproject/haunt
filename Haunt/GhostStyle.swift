import UIKit

/// A selectable ghost. Each carries a `referenceAsset` — a bundled ghost image fed to
/// nano-banana as a SECOND image so the summoned ghost matches the art. The engine's
/// reference-composite prompt extracts ONLY the ghost and keeps the user's room intact.
struct GhostStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let referenceAsset: String
    var referenceImage: UIImage? { UIImage(named: referenceAsset) }

    static let library: [GhostStyle] = [
        .init(id: "g01", name: "The Watcher",   referenceAsset: "ghost_01"),
        .init(id: "g02", name: "The Sitting",   referenceAsset: "ghost_02"),
        .init(id: "g03", name: "The Doorway",   referenceAsset: "ghost_03"),
        .init(id: "g04", name: "The Hall",      referenceAsset: "ghost_04"),
        .init(id: "g05", name: "The Glow",      referenceAsset: "ghost_05"),
        .init(id: "g06", name: "The Bedside",   referenceAsset: "ghost_06"),
        .init(id: "g07", name: "The Static",    referenceAsset: "ghost_07"),
        .init(id: "g08", name: "The Chair",     referenceAsset: "ghost_08"),
        .init(id: "g09", name: "The Parlor",    referenceAsset: "ghost_09"),
        .init(id: "g10", name: "The Skylight",  referenceAsset: "ghost_10"),
        .init(id: "g11", name: "The Mist",      referenceAsset: "ghost_11"),
        .init(id: "g12", name: "The Vigil",     referenceAsset: "ghost_12"),
        .init(id: "g13", name: "The Ceiling",   referenceAsset: "ghost_13"),
        .init(id: "g14", name: "The Threshold", referenceAsset: "ghost_14"),
        .init(id: "g15", name: "The Corridor",  referenceAsset: "ghost_15")
    ]

    static var random: GhostStyle { library.randomElement()! }
}
