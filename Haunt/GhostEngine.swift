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
    Image 1 is the user's real photo. Image 2 shows a specific ghost. Add that EXACT ghost to Image 1 like a real \
    apparition ACCIDENTALLY CAUGHT in a snapshot. Do NOT center it and do NOT make it pose. Instead hide it: \
    place it off to one side, deep in the background, partly concealed behind furniture or a door frame, down a \
    hallway, peering from a doorway, reflected in a mirror/dark window, or half-cut by the edge of the frame. \
    It can be small and distant or lurking at the periphery. Faint, semi-transparent, easy to miss at first glance \
    then unmistakable. Ground it (floor contact, soft shadow, the room's own light). Deepen the shadows around it. \
    Keep the room's layout, furniture and lighting recognizable. Photoreal, deeply unsettling, no text or watermark.
    """

    func summon(from photo: UIImage) {
        guard credits.canSummon else { showPaywall = true; Analytics.track("paywall_shown", ["trigger": "no_credits"]); return }
        errorText = nil; result = nil; isSummoning = true
        let style = selectedStyle ?? .random
        Analytics.track("ghost_summon_started", ["style": style.id, "surprise": selectedStyle == nil])
        let prompt = composePrompt
        Task {
            do {
                let img = try await GhostAPI.summonGhost(into: photo, prompt: prompt, reference: style.referenceImage)
                self.result = img
                self.ghostCount += 1
                self.isSummoning = false
                self.credits.spend()          // charge ONLY on success — failed summons are free
                SummonStore.shared.save(img, original: photo, preset: style.name, mode: "Realistic")
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
