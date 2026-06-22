import SwiftUI

/// Native in-app feedback — sends straight to PostHog as a `feedback_submitted` event.
/// No Google Form, no leaving the app.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    if sent {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle").font(.system(size: 44)).foregroundStyle(.white)
                            Text("THANK YOU").font(.system(.headline, design: .monospaced)).tracking(2).foregroundStyle(.white)
                        }
                    } else {
                        Text("Tell us what's haunting you — bugs, ideas, anything.")
                            .font(.system(.subheadline, design: .monospaced)).foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center).padding(.top, 8)
                        TextEditor(text: $text)
                            .scrollContentBackground(.hidden)
                            .padding(12).frame(height: 180)
                            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                        Button { send() } label: {
                            Text("SEND").font(.system(.subheadline, design: .monospaced).weight(.bold)).tracking(2)
                                .foregroundStyle(.black).frame(maxWidth: .infinity).frame(height: 52)
                                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                        }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                    }
                }.padding()
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() }.foregroundStyle(.white) } }
            .preferredColorScheme(.dark)
        }
    }

    private func send() {
        Analytics.track("feedback_submitted", ["message": text])
        Haptics.tap()
        withAnimation { sent = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
    }
}
