import UIKit

/// Ghost compositing via fal.ai `nano-banana-2/edit`.
/// POST https://fal.run/fal-ai/nano-banana-2/edit
///   headers: Authorization: Key <id:secret> | Content-Type: application/json
///   body:    { "prompt": "...", "image_urls": ["data:image/jpeg;base64,..."] }
///   resp:    { "images": [ { "url": "https://fal.media/..." } ], "description": "..." }
/// Note: fal returns hosted image URLs (not base64), so we download the result.
enum GhostError: Error, LocalizedError {
    case noCredits, contentBlocked, rateLimited, tooLarge, badImage, badKey, network(String)
    var errorDescription: String? {
        switch self {
        case .noCredits:      return "fal balance empty — top up your fal account."
        case .contentBlocked: return "The spirits resisted that one. Try another room."
        case .rateLimited:    return "Too fast — let the veil settle a moment."
        case .tooLarge:       return "That photo's too big. Try another."
        case .badImage:       return "Couldn't read that photo."
        case .badKey:         return "fal key missing or invalid — check Secrets.swift."
        case .network(let m): return m
        }
    }
}

enum GhostAPI {
    static let editURL = URL(string: "https://fal.run/fal-ai/nano-banana-2/edit")!

    static func summonGhost(into photo: UIImage, prompt: String, reference: UIImage? = nil) async throws -> UIImage {
        guard let jpeg = photo.jpegData(compressionQuality: 0.85) else { throw GhostError.badImage }
        func uri(_ img: UIImage) -> String? {
            img.jpegData(compressionQuality: 0.85).map { "data:image/jpeg;base64," + $0.base64EncodedString() }
        }
        // First image = the user's photo (the scene to keep). Optional second = ghost reference art.
        var imageURLs = ["data:image/jpeg;base64," + jpeg.base64EncodedString()]
        if let ref = reference, let refURI = uri(ref) { imageURLs.append(refURI) }

        var req = URLRequest(url: editURL)
        req.httpMethod = "POST"
        req.setValue("Key \(Secrets.falKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 90
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "prompt": prompt,
            "image_urls": imageURLs,
            "num_images": 1
        ])

        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) }
        catch { throw GhostError.network("No connection to the other side. Check your internet.") }

        guard let http = resp as? HTTPURLResponse else { throw GhostError.network("Unexpected response.") }
        switch http.statusCode {
        case 200: break
        case 401, 403: throw GhostError.badKey
        case 402:      throw GhostError.noCredits
        case 422:      throw GhostError.contentBlocked
        case 429:      throw GhostError.rateLimited
        case 413:      throw GhostError.tooLarge
        default:       throw GhostError.network("Summon failed (\(http.statusCode)).")
        }

        guard let url = firstImageURL(in: data) else { throw GhostError.network("Got a reply with no image.") }
        let (imgData, _) = try await URLSession.shared.data(from: url)
        guard let img = UIImage(data: imgData) else { throw GhostError.network("Couldn't decode the ghost image.") }
        return img
    }

    /// fal returns { images: [ { url } ] }. Pull the first url.
    private static func firstImageURL(in data: Data) -> URL? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let arr = json["images"] as? [[String: Any]],
           let s = arr.first?["url"] as? String, let u = URL(string: s) { return u }
        if let s = json["image"] as? String, let u = URL(string: s) { return u }   // fallback shape
        return nil
    }
}
