import UIKit

/// A selectable ghost the user can summon. `prompt` is the eerie description fed to
/// nano-banana (avoids gore wording so the content filter passes). `referenceAsset`
/// is an OPTIONAL bundled image of the ghost — when set, it's sent to the model as a
/// second reference so the summoned ghost matches your hand-made art. Drop PNGs into
/// the asset catalog and set the name here as you build the library.
struct GhostStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let prompt: String
    var referenceAsset: String? = nil

    /// Reference image loaded from the bundle/asset catalog, if any.
    var referenceImage: UIImage? { referenceAsset.flatMap { UIImage(named: $0) } }

    static let library: [GhostStyle] = [
        .init(id: "victorian", name: "The Lady",     emoji: "🕯️", prompt: "insert a translucent, pale Victorian woman in a faded mourning dress, hollow eyes, long dark hair, partially see-through, eerie and unsettling."),
        .init(id: "shadow",    name: "Shadow",       emoji: "🌑", prompt: "insert a tall featureless dark shadow figure standing in the background, no face, only a black silhouette of a person, deeply unsettling."),
        .init(id: "child",     name: "The Child",    emoji: "🧸", prompt: "insert a small pale translucent child standing still and facing away, faded vintage clothes, liminal and eerie."),
        .init(id: "oldwoman",  name: "The Crone",    emoji: "👁️", prompt: "insert a gaunt elderly woman with hollow eyes and drained colorless skin, half-hidden in shadow, see-through and uncanny."),
        .init(id: "soldier",   name: "The Soldier",  emoji: "🎖️", prompt: "insert a faint translucent figure in a tattered old military uniform, hollow stare, desaturated and ghostly."),
        .init(id: "veiled",    name: "The Veiled",   emoji: "👰", prompt: "insert a pale figure draped in a long translucent veil obscuring the face, motionless, eerie and liminal.")
    ]

    static var random: GhostStyle { library.randomElement()! }
}
