import UIKit

/// Talks to the Moondraft REST API (`/v1/edit`) to composite a ghost into a user photo.
/// Contract: POST https://moondraft.ai/v1/edit
///   headers: Authorization: Bearer md_...  | Content-Type: application/json
///   body:    { "prompt": "...", "image": "data:image/png;base64,..." }
///   resp:    image returned as base64 data-URI; 1 credit/edit; 10 req/min.
///   errors:  402 no credits, 422 content-policy, 429 rate limit, 413 too large.
enum MoondraftError: Error, LocalizedError {
    case noCredits, contentBlocked, rateLimited, tooLarge, badImage, network(String)
    var errorDescription: String? {
        switch self {
        case .noCredits:      return "Out of summons. Top up to keep hunting."
        case .contentBlocked: return "The spirits resisted that one. Try another room."
        case .rateLimited:    return "Too fast — let the veil settle a moment."
        case .tooLarge:       return "That photo's too big. Try another."
        case .badImage:       return "Couldn't read that photo."
        case .network(let m): return m
        }
    }
}

struct MoondraftClient {
    /// TODO(cody): paste a Moondraft API key (md_...) from your dashboard, or load from Keychain.
    /// Each ghost = 1 credit. 50 free on signup; packs 100/$9.99.
    static let apiKey = "md_PASTE_KEY_HERE"
    static let editURL = URL(string: "https://moondraft.ai/v1/edit")!

    /// Sends the user's photo + the ghost prompt, returns the haunted image.
    static func summonGhost(into photo: UIImage, prompt: String) async throws -> UIImage {
        guard let jpeg = photo.jpegData(compressionQuality: 0.85) else { throw MoondraftError.badImage }
        let dataURI = "data:image/jpeg;base64," + jpeg.base64EncodedString()

        var req = URLRequest(url: editURL)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        req.httpBody = try JSONEncoder().encode(["prompt": prompt, "image": dataURI])

        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw MoondraftError.network("No connection to the other side. Check your internet.") }

        guard let http = resp as? HTTPURLResponse else { throw MoondraftError.network("Unexpected response.") }
        switch http.statusCode {
        case 200: break
        case 402: throw MoondraftError.noCredits
        case 422: throw MoondraftError.contentBlocked
        case 429: throw MoondraftError.rateLimited
        case 413: throw MoondraftError.tooLarge
        default:  throw MoondraftError.network("Summon failed (\(http.statusCode)).")
        }

        // Response carries the image as a base64 data-URI. Pull the first base64 blob we find.
        guard let img = Self.decodeImage(from: data) else { throw MoondraftError.network("Got a reply with no image.") }
        return img
    }

    /// Robustly extract a UIImage from JSON whose image field may be `image`, `images[0]`, or a data-URI string.
    private static func decodeImage(from data: Data) -> UIImage? {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        func b64(_ s: String) -> UIImage? {
            let raw = s.contains(",") ? String(s.split(separator: ",").last ?? "") : s
            guard let d = Data(base64Encoded: raw) else { return nil }
            return UIImage(data: d)
        }
        if let dict = json as? [String: Any] {
            for key in ["image", "result", "url", "data"] {
                if let s = dict[key] as? String, let img = b64(s) { return img }
            }
            if let arr = dict["images"] as? [String], let first = arr.first, let img = b64(first) { return img }
            if let arr = dict["images"] as? [[String: Any]], let s = arr.first?["image"] as? String, let img = b64(s) { return img }
        }
        return nil
    }
}
