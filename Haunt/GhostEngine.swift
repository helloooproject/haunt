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

    // Reference-composite prompt. Image 1 = the user's photo (their room). Image 2 = the chosen ghost.
    // The whole point: take ONLY the ghost from Image 2; keep their room exactly theirs.
    private let composePrompt = """
    You are given two images. Image 1 is the user's real photo. Image 2 shows a ghost. \
    Composite ONLY the ghostly figure from Image 2 into Image 1 as a translucent, eerie apparition. \
    CRITICAL: keep Image 1's room, walls, furniture, floor, lighting, colors and composition EXACTLY as they are — \
    do NOT import the room, background, walls or floor from Image 2. Take ONLY the ghost itself. \
    Scale, place and light the ghost naturally to match Image 1's perspective and lighting. Photoreal, unsettling.
    """

    // "Cinematic" mode: same ghost, but also grade their room into a film-horror look.
    private let cinematicPrompt = """
    You are given two images. Image 1 is the user's real photo. Image 2 shows a ghost. \
    Composite ONLY the ghostly figure from Image 2 into Image 1, and re-grade Image 1 into a dark, \
    desaturated, cinematic horror atmosphere (deep shadows, cold tones, subtle film grain, moody contrast). \
    Keep the room recognizably the SAME room and layout as Image 1 — do not import Image 2's room — but darken it cinematically. Photoreal.
    """

    /// false = Keep my room (truthful), true = Cinematic (graded).
    @AppStorage("cinematic") var cinematic = false

    func summon(from photo: UIImage) {
        if !unlocked && freeRemaining == 0 { showPaywall = true; Analytics.track("paywall_shown", ["trigger": "free_limit"]) ; return }
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
