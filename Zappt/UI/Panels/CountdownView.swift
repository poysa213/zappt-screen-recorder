import SwiftUI

/// A large animated 3-2-1 countdown shown before recording begins.
struct CountdownView: View {
    let count: Int

    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 220, height: 220)
                .overlay(Circle().stroke(Theme.accent.opacity(0.4), lineWidth: 6))
                .shadow(color: .black.opacity(0.2), radius: 30)

            Text("\(count)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.accent)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            scale = 0.6
            opacity = 0
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
        }
        .id(count)
    }
}
