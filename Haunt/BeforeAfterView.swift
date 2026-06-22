import SwiftUI

/// The 'aha': the haunted image is unveiled over the original with a slow eerie wipe that
/// FULLY reveals the ghost (settles with a subtle push-in), then leaves a draggable divider
/// so you can slide back to compare. The reveal IS the shareable moment.
struct BeforeAfterView: View {
    let before: UIImage
    let after: UIImage
    @State private var split: CGFloat = 1      // 1 = all "before"; animates to 0 = full haunted
    @State private var revealed = false
    @State private var showHint = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                Image(uiImage: after).resizable().scaledToFit()
                    .frame(width: w)
                    .scaleEffect(revealed ? 1.0 : 1.06)        // settle-in push
                Image(uiImage: before).resizable().scaledToFit()
                    .frame(width: w)
                    .mask(alignment: .leading) { Rectangle().frame(width: max(0, w * split)) }

                if split > 0.001 { handle(at: w * split, height: geo.size.height) }

                if showHint {
                    Text("DRAG TO COMPARE")
                        .font(.system(.caption2, design: .monospaced)).tracking(2)
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.black.opacity(0.4), in: Capsule())
                        .frame(width: w).frame(maxHeight: geo.size.height, alignment: .bottom)
                        .padding(.bottom, 14).transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                if showHint { withAnimation { showHint = false } }
                split = min(1, max(0, v.location.x / w))
            })
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .onAppear {
                split = 1; revealed = false
                withAnimation(.easeInOut(duration: 1.9)) { split = 0; revealed = true }   // full reveal
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) { withAnimation { showHint = true } }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { withAnimation { showHint = false } }
            }
        }
    }

    private func handle(at x: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(.white).frame(width: 2)
                .shadow(color: .white.opacity(0.7), radius: 8)        // eerie glow on the seam
            Circle().fill(.white).frame(width: 34, height: 34)
                .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.black))
                .shadow(color: .black.opacity(0.4), radius: 4)
        }
        .position(x: x, y: height / 2)
        .allowsHitTesting(false)
    }
}
