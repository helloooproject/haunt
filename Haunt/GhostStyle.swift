import UIKit

/// A selectable apparition archetype. `poster` is the carousel art; `prompt` is the entity
/// description composited into the user's photo at summon time (no sheet reference — the old
/// bedsheet look is gone). Each archetype is a distinct kind of horror.
struct GhostStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let posterAsset: String
    let prompt: String
    var posterImage: UIImage? { UIImage(named: posterAsset) }

    static let library: [GhostStyle] = [
        .init(id: "shadow", name: "The Shadow", posterAsset: "ghost_01",
              prompt: "a featureless pitch-black humanoid shadow figure, darker than the surrounding darkness, with faint glowing eyes"),
        .init(id: "palewoman", name: "The Pale Woman", posterAsset: "ghost_02",
              prompt: "a pale gaunt woman with long stringy black hair hanging over her hidden face, ashen skin, in a dirty white gown"),
        .init(id: "tall", name: "The Tall One", posterAsset: "ghost_03",
              prompt: "an unnaturally tall, thin, pale figure with no face and elongated limbs, wrong proportions, looming"),
        .init(id: "victorian", name: "The Victorian", posterAsset: "ghost_04",
              prompt: "a translucent glowing apparition of a Victorian woman in a lace mourning dress, faintly luminous and semi-transparent"),
        .init(id: "child", name: "The Child", posterAsset: "ghost_05",
              prompt: "the faint translucent ghost of a small pale child standing still and facing away, deeply eerie"),
        .init(id: "hollow", name: "The Hollow", posterAsset: "ghost_06",
              prompt: "a gaunt ashen ghostly figure with black hollow eye sockets, draped in tattered grey cloth"),
        .init(id: "crawler", name: "The Crawler", posterAsset: "ghost_07",
              prompt: "a contorted pale ghost crawling low across the floor, limbs bent the wrong way, long hair hanging over its face"),
        .init(id: "mist", name: "The Mist", posterAsset: "ghost_08",
              prompt: "a swirling translucent ectoplasmic mist coalescing into a faceless humanoid figure"),
        .init(id: "watcher", name: "The Watcher", posterAsset: "ghost_09",
              prompt: "a figure standing in the deepest shadow, only its pale gaunt face and glowing eyes catching the dim light")
    ]

    static var random: GhostStyle { library.randomElement()! }
}
