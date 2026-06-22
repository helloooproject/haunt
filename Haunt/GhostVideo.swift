import UIKit
import AVFoundation

/// Builds an MP4 that slow-crossfades the original photo → haunted image, so the ghost
/// materializes in place. Realistic mode only (room unchanged → only the ghost appears).
enum GhostVideo {
    static func makeFade(original: UIImage, haunted: UIImage, duration: Double = 4.0, fps: Int = 24) async -> URL? {
        let size = cappedEvenSize(haunted.size, maxDim: 720)
        guard size.width >= 2, size.height >= 2,
              let before = render(original, to: size)?.cgImage,
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
        guard writer.startWriting() else { return nil }
        writer.startSession(atSourceTime: .zero)

        let total = max(2, Int(duration * Double(fps)))
        let rect = CGRect(origin: .zero, size: size)
        var ok = true
        for i in 0..<total {
            while !input.isReadyForMoreMediaData {
                try? await Task.sleep(nanoseconds: 5_000_000)
                if writer.status != .writing { ok = false; break }
            }
            if !ok { break }
            let appended = autoreleasepool { () -> Bool in
                guard let pool = adaptor.pixelBufferPool else { return false }
                var pbOut: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pbOut) == kCVReturnSuccess,
                      let buffer = pbOut else { return false }
                CVPixelBufferLockBaseAddress(buffer, [])
                defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
                guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                          width: Int(size.width), height: Int(size.height),
                                          bitsPerComponent: 8,
                                          bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return false }
                ctx.translateBy(x: 0, y: size.height); ctx.scaleBy(x: 1, y: -1)
                ctx.draw(before, in: rect)                 // original underneath
                ctx.setAlpha(fadeAlpha(Double(i) / Double(total - 1)))
                ctx.draw(after, in: rect)                  // haunted fades in (ghost materializes)
                return adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: CMTimeScale(fps)))
            }
            if !appended { ok = false; break }
        }
        input.markAsFinished()
        await writer.finishWriting()
        return (ok && writer.status == .completed) ? url : nil
    }

    /// Hold original, smoothstep the ghost in, hold haunted.
    private static func fadeAlpha(_ t: Double) -> Double {
        let s = 0.18, e = 0.82
        if t <= s { return 0 }
        if t >= e { return 1 }
        let x = (t - s) / (e - s)
        return x * x * (3 - 2 * x)
    }

    private static func cappedEvenSize(_ s: CGSize, maxDim: CGFloat) -> CGSize {
        guard s.width > 0, s.height > 0 else { return .zero }
        let m = max(s.width, s.height)
        let scale = m > maxDim ? maxDim / m : 1
        func even(_ v: CGFloat) -> CGFloat { let i = Int((v * scale).rounded()); return CGFloat(max(2, i - (i % 2))) }
        return CGSize(width: even(s.width), height: even(s.height))
    }

    private static func render(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
