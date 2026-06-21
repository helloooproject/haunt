import SwiftUI

/// The 'aha': on result, wipe from the user's original photo to the haunted version,
/// then leave a draggable divider so they can compare. The reveal IS the shareable moment.
struct BeforeAfterView: View {
    let before: UIImage
    let after: UIImage
    @State private var split: CGFloat = 1   // 1 = all "before", animates to ~0.5

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .topLeading) {
                Image(uiImage: after).resizable().scaledToFit()
                    .frame(width: w)
                Image(uiImage: before).resizable().scaledToFit()
                    .frame(width: w)
                    .mask(alignment: .leading) { Rectangle().frame(width: max(0, w * split)) }

                // divider handle
                handle(at: w * split, height: geo.size.height)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                split = min(1, max(0, v.location.x / w))
            })
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .onAppear {
                split = 1
                withAnimation(.easeInOut(duration: 1.3)) { split = 0.5 }   // auto-reveal
            }
        }
    }

    private func handle(at x: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(.white).frame(width: 2)
            Circle().fill(.white).frame(width: 34, height: 34)
                .overlay(Image(systemName: "arrow.left.and.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.black))
                .shadow(radius: 4)
        }
        .position(x: x, y: height / 2)
        .allowsHitTesting(false)
    }
}
