import UIKit

/// Brands a summoned ghost before sharing — so every share is an ad for Haunt.
/// Subtle bottom watermark: the "Haunt" wordmark + a small tagline. The growth loop.
enum ShareCard {
    static func brand(_ image: UIImage) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = image.scale; f.opaque = true; return f }())
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))

            let pad = size.width * 0.045
            // soft gradient scrim so the mark is legible on any photo
            // wordmark
            let markSize = size.width * 0.075
            let markFont = UIFont(name: "PicNic-Regular", size: markSize) ?? .systemFont(ofSize: markSize, weight: .heavy)
            let shadow = NSShadow(); shadow.shadowColor = UIColor.black.withAlphaComponent(0.8)
            shadow.shadowBlurRadius = size.width * 0.02; shadow.shadowOffset = .zero
            let mark = NSAttributedString(string: "Haunt", attributes: [
                .font: markFont, .foregroundColor: UIColor.white, .shadow: shadow
            ])
            let mSize = mark.size()
            let mY = size.height - mSize.height - pad
            mark.draw(at: CGPoint(x: pad, y: mY))

            // tagline under the mark
            let tagSize = size.width * 0.028
            let tagFont = UIFont.monospacedSystemFont(ofSize: tagSize, weight: .semibold)
            let tag = NSAttributedString(string: "made with Haunt", attributes: [
                .font: tagFont, .foregroundColor: UIColor.white.withAlphaComponent(0.75), .shadow: shadow,
                .kern: tagSize * 0.15
            ])
            tag.draw(at: CGPoint(x: pad + 2, y: mY + mSize.height - tagSize * 0.4))
        }
    }
}
