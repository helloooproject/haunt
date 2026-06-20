import Foundation

/// Thin PostHog wrapper. Swap the print for the PostHog SDK once the key is added.
/// Funnel we care about: open → scan → ghost_summon_started → ghost_rendered → shared → paywall_shown → purchased.
enum Analytics {
    /// TODO(cody): add PostHog SDK + project key, then replace the body.
    static func track(_ event: String, _ props: [String: Any] = [:]) {
        #if DEBUG
        print("📊 \(event) \(props)")
        #endif
        // PostHogSDK.shared.capture(event, properties: props)
    }
}
