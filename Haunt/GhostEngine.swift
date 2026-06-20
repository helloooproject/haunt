import SwiftUI
import StoreKit

/// Owns the ghost prompt, the free-gen limit, and the "positive moment" review trigger.
@MainActor
final class GhostEngine: ObservableObject {
    @Published var isSummoning = false
    @Published var result: UIImage?
    @Published var errorText: String?
    @Published var showPaywall = false

    private let freeLimit = 2
    @AppStorage("ghostCount") private var ghostCount = 0
    @AppStorage("hasPro") var hasPro = false

    var freeRemaining: Int { max(0, freeLimit - ghostCount) }

    /// Photoreal-creepy ghost prompts. NOTE: Moondraft's content filter blocks
    /// "demonic / blood / gore / horror" wording (→ fail + auto-refund). These use
    /// "eerie / hollow-eyed / liminal / translucent" which reads creepy without tripping it.
    // Hard rule: preserve the original photo pixel-for-pixel and ONLY insert a ghost.
    // (nano-banana can drift/regenerate, so every prompt leads with "do not change the photo".)
    private let preserve = "Do NOT change, regenerate, restyle, recolor, or replace the original photo or its background. Keep every existing pixel, the lighting, and the composition exactly as-is. Make ONLY this one addition: "
    private let prompts = [
        "insert a single translucent, pale human figure standing in the existing background — hollow eyes, faded Victorian clothing, partially see-through, eerie and unsettling. Match the photo's real lighting. Photoreal ghost composited into the untouched scene.",
        "insert a faint ghostly apparition into the existing scene: a gaunt translucent person half-hidden in shadow, blurred and liminal, hollow dark eye sockets, desaturated. Photoreal, uncanny. Nothing else in the photo changes.",
        "insert a pale see-through spectral figure in a corner of the existing photo — long hair over the face, drained colorless skin, slightly motion-blurred as if caught moving. Photoreal ghost, eerie. The rest of the photo stays identical."
    ]
    private var ghostPrompt: String { preserve + prompts.randomElement()! }

    func summon(from photo: UIImage) {
        if !hasPro && freeRemaining == 0 { showPaywall = true; Analytics.track("paywall_shown", ["trigger": "free_limit"]) ; return }
        errorText = nil; result = nil; isSummoning = true
        Analytics.track("ghost_summon_started")
        let prompt = ghostPrompt
        Task {
            do {
                let img = try await GhostAPI.summonGhost(into: photo, prompt: prompt)
                self.result = img
                self.ghostCount += 1
                self.isSummoning = false
                Analytics.track("ghost_rendered", ["count": self.ghostCount])
                self.maybeAskForReview()      // positive moment: a ghost just appeared
            } catch {
                self.isSummoning = false
                self.errorText = (error as? LocalizedError)?.errorDescription ?? "The summon failed."
                Analytics.track("ghost_failed", ["error": "\(error)"])
                if case GhostError.noCredits = error { self.showPaywall = true }
            }
        }
    }

    /// Fire SKStoreReview after the FIRST successful ghost (the wow), never on launch.
    private func maybeAskForReview() {
        guard ghostCount == 1 else { return }
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
