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

    /// Paywall gate. In DEBUG we're always unlocked so testing isn't blocked by the free limit.
    var unlocked: Bool {
        #if DEBUG
        return true
        #else
        return hasPro
        #endif
    }

    var freeRemaining: Int { max(0, freeLimit - ghostCount) }

    /// Photoreal-creepy ghost prompts. NOTE: Moondraft's content filter blocks
    /// "demonic / blood / gore / horror" wording (→ fail + auto-refund). These use
    /// "eerie / hollow-eyed / liminal / translucent" which reads creepy without tripping it.
    /// nil = "Surprise me" (random each summon). Otherwise the user's picked ghost.
    @Published var selectedStyle: GhostStyle?

    // Hard rule: preserve the original photo pixel-for-pixel and ONLY insert the ghost.
    private let preserve = "Do NOT change, regenerate, restyle, recolor, or replace the original photo or its background. Keep every existing pixel, the lighting, and the composition exactly as-is. Make ONLY this one addition (photoreal, matching the photo's real lighting): "

    func summon(from photo: UIImage) {
        if !unlocked && freeRemaining == 0 { showPaywall = true; Analytics.track("paywall_shown", ["trigger": "free_limit"]) ; return }
        errorText = nil; result = nil; isSummoning = true
        let style = selectedStyle ?? .random
        Analytics.track("ghost_summon_started", ["style": style.id, "surprise": selectedStyle == nil])
        let prompt = preserve + style.prompt
        Task {
            do {
                let img = try await GhostAPI.summonGhost(into: photo, prompt: prompt, reference: style.referenceImage)
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
