import UIKit
import AVFoundation

/// Builds an MP4 that slow-crossfades the original photo → haunted image, so the ghost
/// materializes in place. Only valid for Realistic mode (the room is unchanged, so only
/// the ghost appears). The shareable "it just appeared" clip.
enum GhostVideo {
    static func makeFade(original: UIImage, haunted: UIImage, duration: Double = 4.0, fps: Int = 30) async -> URL? {
        let size = cappedSize(haunted.size, maxDim: 1080)
        guard let before = render(original, to: size)?.cgImage,
              let after = render(haunted, to: size)?.cgImage else { return nil }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("haunt_\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return nil }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height)
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ])
        guard writer.canAdd(input) else { return nil }
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let total = max(1, Int(duration * Double(fps)))
        let rect = CGRect(origin: .zero, size: size)
        for i in 0..<total {
            while !input.isReadyForMoreMediaData { try? await Task.sleep(nanoseconds: 4_000_000) }
            let a = fadeAlpha(Double(i) / Double(total - 1))
            // Composite the frame: original, then haunted at alpha a (only the ghost differs → it fades in).
            let frame = UIGraphicsImageRenderer(size: size).image { ctx in
                let cg = ctx.cgContext
                cg.draw(before, in: rect)
                cg.setAlpha(a)
                cg.draw(after, in: rect)
            }
            guard let buf = pixelBuffer(from: frame.cgImage, size: size) else { continue }
            adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        return writer.status == .completed ? url : nil
    }

    /// Hold original ~0.8s, ramp the ghost in, hold haunted at the end. Smoothstep ramp.
    private static func fadeAlpha(_ t: Double) -> Double {
        let s = 0.18, e = 0.82
        if t <= s { return 0 }
        if t >= e { return 1 }
        let x = (t - s) / (e - s)
        return x * x * (3 - 2 * x)
    }

    private static func cappedSize(_ s: CGSize, maxDim: CGFloat) -> CGSize {
        let m = max(s.width, s.height)
        let scale = m > maxDim ? maxDim / m : 1
        // even dimensions for H264
        func even(_ v: CGFloat) -> CGFloat { let i = Int(v * scale); return CGFloat(i - (i % 2)) }
        return CGSize(width: max(2, even(s.width)), height: max(2, even(s.height)))
    }

    private static func render(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func pixelBuffer(from cgImage: CGImage?, size: CGSize) -> CVPixelBuffer? {
        guard let cgImage else { return nil }
        var pb: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                            kCVPixelFormatType_32ARGB, attrs, &pb)
        guard let buffer = pb else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                  width: Int(size.width), height: Int(size.height),
                                  bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }
        // Flip: CVPixelBuffer/CGContext origin is bottom-left; our CGImage is top-left.
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}
