import Foundation
import UIKit

/// Lightweight PostHog capture over HTTP — no SDK/SPM dependency.
/// Shared RCI "Default project"; Haunt events are tagged `app: "haunt"` for filtering.
/// Funnel: app_open → photo_captured → ghost_summon_started → ghost_rendered → shared → paywall_shown → purchased.
enum Analytics {
    private static let key = "phc_m4RedTwvftUvna1Cg39D6ap5cAzjNus1CdFsFjnuNTt"
    private static let host = "https://us.i.posthog.com"

    /// Stable anonymous id per install.
    private static let distinctID: String = {
        let k = "ph_distinct_id"
        if let s = UserDefaults.standard.string(forKey: k) { return s }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: k)
        return id
    }()

    private static let appVersion: String =
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"

    static func track(_ event: String, _ props: [String: Any] = [:]) {
        #if DEBUG
        print("📊 \(event) \(props)")
        #endif
        var properties = props
        properties["app"] = "haunt"
        properties["$lib"] = "haunt-ios"
        properties["app_version"] = appVersion

        let body: [String: Any] = [
            "api_key": key,
            "event": event,
            "distinct_id": distinctID,
            "properties": properties
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: body),
              let url = URL(string: "\(host)/capture/") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data
        URLSession.shared.dataTask(with: req).resume()   // fire-and-forget
    }
}
