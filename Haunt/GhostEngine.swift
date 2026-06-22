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

    // Single-image composite. The ghost is described by the chosen archetype (no sheet reference).
    private func composePrompt(for style: GhostStyle) -> String {
        """
        This is the user's real photo. Composite a frightening ghost into it: \(style.prompt). \
        PLACEMENT: do not center it or make it pose — position it off to one side, in the background, in a doorway, \
        behind furniture, or near the edge of the frame, as if caught on camera unintentionally. \
        The ghost must be CLEARLY VISIBLE and solid enough to read instantly as a figure, grounded with a soft \
        shadow and lit by the room's own light, with deepened shadows around it. \
        Keep the room's layout, furniture and lighting exactly as they are. Photoreal, deeply unsettling, no text or watermark.
        """
    }

    func summon(from photo: UIImage) {
        guard credits.canSummon else { showPaywall = true; Analytics.track("paywall_shown", ["trigger": "no_credits"]); return }
        errorText = nil; result = nil; isSummoning = true
        let style = selectedStyle ?? .random
        Analytics.track("ghost_summon_started", ["style": style.id, "surprise": selectedStyle == nil])
        let prompt = composePrompt(for: style)
        Task {
            do {
                let img = try await GhostAPI.summonGhost(into: photo, prompt: prompt, reference: nil)
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
