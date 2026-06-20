import SwiftUI

/// Static film-grain overlay drawn once — adds analog texture without per-frame cost.
struct GrainOverlay: View {
    var intensity: Double = 0.06
    var body: some View {
        Canvas { ctx, size in
            var rng = SeededRNG(seed: 8675309)
            let count = Int(size.width * size.height / 700)
            for _ in 0..<count {
                let x = Double.random(in: 0...size.width, using: &rng)
                let y = Double.random(in: 0...size.height, using: &rng)
                let a = Double.random(in: 0...intensity, using: &rng)
                let s = Double.random(in: 0.5...1.4, using: &rng)
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: s, height: s)),
                         with: .color(.white.opacity(a)))
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// Deterministic RNG so the grain pattern is stable across redraws.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0xdeadbeef : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
}

/// Dark vignette to pull focus to center — cinematic framing.
struct Vignette: View {
    var body: some View {
        RadialGradient(colors: [.clear, .black.opacity(0.55)],
                       center: .center, startRadius: 120, endRadius: 480)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}

/// Candle-flicker modifier: irregular opacity + soft glow. For the wordmark.
struct Flicker: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .opacity(on ? 1.0 : 0.82)
            .shadow(color: .white.opacity(on ? 0.5 : 0.15), radius: on ? 14 : 6)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true).delay(.random(in: 0...0.3))) {
                    on = true
                }
            }
    }
}
extension View { func flicker() -> some View { modifier(Flicker()) } }
