import SwiftUI
import StoreKit

/// Owns the ghost prompt, the free-gen limit, and the "positive moment" review trigger.
@MainActor
final class GhostEngine: ObservableObject {
    @Published var isSummoning = false
    @Published var result: UIImage?
    @Published var errorText: String?
    @Published var showPaywall = false

    @AppStorage("ghostCount") private var ghostCount = 0
    private let credits = CreditStore.shared

    /// Photoreal-creepy ghost prompts. NOTE: Moondraft's content filter blocks
    /// "demonic / blood / gore / horror" wording (→ fail + auto-refund). These use
    /// "eerie / hollow-eyed / liminal / translucent" which reads creepy without tripping it.
    /// nil = "Surprise me" (random each summon). Otherwise the user's picked ghost.
    @Published var selectedStyle: GhostStyle?

    // Reference-composite prompt. Image 1 = the user's photo (their room). Image 2 = the chosen ghost.
    // The whole point: take ONLY the ghost from Image 2; keep their room exactly theirs.
    private let composePrompt = """
    Image 1 is the user's real photo. Image 2 shows a specific ghost. Place that EXACT ghost into Image 1 but \
    STAGE IT TO BE GENUINELY FRIGHTENING: positioned unsettlingly close to the camera OR emerging from a dark \
    doorway/corner, slightly too tall, head tilted at an unnatural angle, with faint motion blur as if it just \
    lurched toward the viewer. Ground it (floor contact, soft shadow, room light), semi-transparent but \
    unmistakably there. Dim the nearby lights and deepen the shadows around it for dread. \
    Keep the room's layout and furniture recognizable. Photoreal, deeply unsettling, no text or watermark.
    """

    // "Cinematic" mode: looming ghost + full horror-film grade.
    private let cinematicPrompt = """
    Image 1 is the user's real photo. Image 2 shows a specific ghost. Place that EXACT ghost LOOMING in Image 1's \
    scene, then grade the entire image like a horror film / found-footage still: crushed blacks, sickly desaturated \
    teal-green pallor, heavy film grain, strong vignette, a single cold low-key light source, faint haze. \
    The ghost menacing and uncanny, partly swallowed by shadow. Keep the same room layout. \
    Photoreal cinematic horror, no text or watermark.
    """

    /// false = Keep my room (truthful), true = Cinematic (graded).
    @AppStorage("cinematic") var cinematic = false

    func summon(from photo: UIImage) {
        guard credits.canSummon else { showPaywall = true; Analytics.track("paywall_shown", ["trigger": "no_credits"]); return }
        errorText = nil; result = nil; isSummoning = true
        let style = selectedStyle ?? .random
        Analytics.track("ghost_summon_started", ["style": style.id, "surprise": selectedStyle == nil, "cinematic": cinematic])
        let prompt = cinematic ? cinematicPrompt : composePrompt
        Task {
            do {
                let img = try await GhostAPI.summonGhost(into: photo, prompt: prompt, reference: style.referenceImage)
                self.result = img
                self.ghostCount += 1
                self.isSummoning = false
                self.credits.spend()          // charge ONLY on success — failed summons are free
                SummonStore.shared.save(img, original: photo, preset: style.name, mode: cinematic ? "Cinematic" : "Realistic")
                Analytics.track("ghost_rendered", ["count": self.ghostCount, "credits_left": self.credits.balance])
                self.maybeAskForReview()      // positive moment: a ghost just appeared
            } catch {
                self.isSummoning = false      // no credit spent on failure
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
