import SwiftUI

struct OrbitHeaderView: View {
    @State private var innerRotation: Double = 0
    @State private var inner2Rotation: Double = 0
    @State private var middleRotation: Double = 0
    @State private var outerRotation: Double = 0

    var body: some View {
        ZStack {
            // 4 Orbits
            orbitRing(radius: 70)
            orbitRing(radius: 100)
            orbitRing(radius: 130)
            orbitRing(radius: 160) // Fits perfectly within 320x320
            
            // 4 Particles (Varying sizes)
            orbitParticle(radius: 70, size: 14, rotation: innerRotation)
            orbitParticle(radius: 100, size: 16, rotation: inner2Rotation) // Counter-clockwise
            orbitParticle(radius: 130, size: 18, rotation: middleRotation) // Clockwise
            orbitParticle(radius: 160, size: 20, rotation: outerRotation) // Counter-clockwise
            
            // ✅ CENTER LOGO - Fixed position
            Image("DomaLogo")
                .renderingMode(.template) // Allows coloring the SVG
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .foregroundStyle(Color.blue) // Tints the template image blue
        }
        .onAppear {
            // Set different speeds and directions
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                innerRotation = 360
            }
            withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
                inner2Rotation = -360 // spins the opposite way
            }
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                middleRotation = 360
            }
            withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
                outerRotation = -360 // spins the opposite way
            }
        }
    }
    
    // MARK: - Helpers
    private func orbitRing(radius: CGFloat) -> some View {
        Circle()
            .stroke(Color.blue.opacity(0.40), style: StrokeStyle(lineWidth: 1.5, dash: [1, 6]))
            .frame(width: radius * 2, height: radius * 2)
    }
    
    private func orbitParticle(radius: CGFloat, size: CGFloat, rotation: Double) -> some View {
        // ZStack wrapper helps set a central pivot point for the dot
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: size, height: size)
                .offset(x: radius) // Push dot to the edge of the radius
        }
        .rotationEffect(.degrees(rotation))
    }
}

