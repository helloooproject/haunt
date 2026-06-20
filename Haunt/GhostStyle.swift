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
        .init(id: "victorian", name: "The Lady",    emoji: "🕯️", prompt: "insert a gaunt, ashen Victorian woman in a tattered mourning dress, hollow black eye sockets, long matted hair hanging over her face, staring directly into the camera, standing far too close, slightly translucent, dread-inducing and deeply wrong."),
        .init(id: "shadow",    name: "Shadow",      emoji: "🌑", prompt: "insert an unnaturally tall, elongated featureless black silhouette looming in the room, faceless, limbs too long, leaning toward the camera, pure dread."),
        .init(id: "child",     name: "The Child",   emoji: "🧸", prompt: "insert a pale hollow-eyed child standing unnaturally still and facing the camera dead-on, ashen skin, faded vintage clothes, wrong proportions, profoundly unsettling."),
        .init(id: "crone",     name: "The Crone",   emoji: "👁️", prompt: "insert a gaunt ashen old woman lunging from the shadows toward the camera, sunken hollow eyes, mouth open in a silent scream, skeletal grasping hands, terrifying and uncanny."),
        .init(id: "tall",      name: "The Tall One",emoji: "🚪", prompt: "insert an impossibly tall, thin pallid figure with a blank featureless face, hunched against the ceiling, watching, limbs unnaturally long, deeply frightening."),
        .init(id: "veiled",    name: "The Veiled",  emoji: "👰", prompt: "insert a pallid figure draped in a torn translucent veil with a gaunt face pressing through the fabric, hollow eyes visible underneath, standing close and staring, dread-filled.")
    ]

    static var random: GhostStyle { library.randomElement()! }
}
