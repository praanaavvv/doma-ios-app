import SwiftUI

struct OrbitHeaderView: View {
    @State private var rotateOuter = false
    @State private var rotateInner = false

    var body: some View {
        ZStack {

            // Outer dotted orbit
            Circle()
                .stroke(
                    Color.blue.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 6])
                )
                .frame(width: 300, height: 300)
                .rotationEffect(.degrees(rotateOuter ? 360 : 0))
                .animation(
                    .linear(duration: 30).repeatForever(autoreverses: false),
                    value: rotateOuter
                )

            // Inner solid orbit
            Circle()
                .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(rotateInner ? -360 : 0))
                .animation(
                    .linear(duration: 18).repeatForever(autoreverses: false),
                    value: rotateInner
                )

            // Orbiting dots
            orbitDot(radius: 150, size: 10, delay: 0)
            orbitDot(radius: 150, size: 8, delay: 1.5)
            orbitDot(radius: 110, size: 7, delay: 3)

            // ✅ CENTER LOGO (UPDATED NAME)
            Image("Domalogo")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .background(
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.08), radius: 8)
                )
        }
        .onAppear {
            rotateOuter = true
            rotateInner = true
        }
    }

    // MARK: - Orbiting Dot
    private func orbitDot(radius: CGFloat, size: CGFloat, delay: Double) -> some View {
        Circle()
            .fill(Color.blue)
            .frame(width: size, height: size)
            .offset(x: radius)
            .rotationEffect(.degrees(rotateOuter ? 360 : 0))
            .animation(
                .linear(duration: 22)
                    .repeatForever(autoreverses: false)
                    .delay(delay),
                value: rotateOuter
            )
    }
}

