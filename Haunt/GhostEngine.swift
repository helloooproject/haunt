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
    private let prompts = [
        "Add a single translucent, pale human figure standing in the background of this exact photo — hollow eyes, faded Victorian clothing, partially see-through, eerie and unsettling. Keep the original room, lighting, and composition unchanged. Photoreal.",
        "Composite a faint ghostly apparition into this real photo: a gaunt translucent person half-hidden in shadow, blurred and liminal, hollow dark eye sockets, desaturated. Do not alter the rest of the scene. Photoreal, uncanny.",
        "Place a pale see-through spectral figure in the corner of this photograph — long hair over the face, drained colorless skin, slightly motion-blurred as if caught moving. Match the photo's real lighting. Eerie, photoreal, untouched background."
    ]

    func summon(from photo: UIImage) {
        if !hasPro && freeRemaining == 0 { showPaywall = true; Analytics.track("paywall_shown", ["trigger": "free_limit"]) ; return }
        errorText = nil; result = nil; isSummoning = true
        Analytics.track("ghost_summon_started")
        let prompt = prompts.randomElement()!
        Task {
            do {
                let img = try await MoondraftClient.summonGhost(into: photo, prompt: prompt)
                self.result = img
                self.ghostCount += 1
                self.isSummoning = false
                Analytics.track("ghost_rendered", ["count": self.ghostCount])
                self.maybeAskForReview()      // positive moment: a ghost just appeared
            } catch {
                self.isSummoning = false
                self.errorText = (error as? LocalizedError)?.errorDescription ?? "The summon failed."
                Analytics.track("ghost_failed", ["error": "\(error)"])
                if case MoondraftError.noCredits = error { self.showPaywall = true }
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
