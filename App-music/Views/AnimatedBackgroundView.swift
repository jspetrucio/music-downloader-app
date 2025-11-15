//
//  AnimatedBackgroundView.swift
//  App-music
//
//  Animated background with audio visualizer and particles
//  Inspired by Apple Music's subtle animations
//

import SwiftUI

// MARK: - Animated Background View

struct AnimatedBackgroundView: View {
    @State private var animationOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Base black background
            Color.black
                .ignoresSafeArea()

            // Subtle gradient that pulses
            RadialGradient(
                colors: [
                    Color.white.opacity(0.03),
                    Color.clear
                ],
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .scaleEffect(pulseScale)
            .ignoresSafeArea()

            // Audio visualizer bars
            AudioVisualizerView()
                .opacity(0.15)
                .ignoresSafeArea()

            // Floating particles
            ParticlesView()
                .opacity(0.1)
                .ignoresSafeArea()
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Pulse animation (like a heartbeat at 60 BPM)
        withAnimation(
            .easeInOut(duration: 3.0)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.2
        }
    }
}

// MARK: - Audio Visualizer View

struct AudioVisualizerView: View {
    @State private var barHeights: [CGFloat] = Array(repeating: 0.2, count: 40)

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: max(2, geometry.size.width / 80)) {
                ForEach(0..<40, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: geometry.size.height * barHeights[index])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            startVisualization()
        }
    }

    private func startVisualization() {
        // Animate each bar with different timing for wave effect
        for index in 0..<barHeights.count {
            let delay = Double(index) * 0.05
            let duration = Double.random(in: 0.8...1.5)

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    barHeights[index] = CGFloat.random(in: 0.1...0.8)
                }
            }
        }
    }
}

// MARK: - Particles View

struct ParticlesView: View {
    @State private var particles: [Particle] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    ParticleView(particle: particle, geometry: geometry)
                }
            }
        }
        .onAppear {
            createParticles()
        }
    }

    private func createParticles() {
        // Create 30 particles
        particles = (0..<30).map { _ in
            Particle(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 2...6),
                speed: CGFloat.random(in: 0.3...0.8),
                isNote: Double.random(in: 0...1) > 0.9 // 10% are musical notes
            )
        }
    }
}

// MARK: - Particle Model

struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let speed: CGFloat
    let isNote: Bool

    var symbol: String {
        ["♪", "♫", "♬"].randomElement() ?? "♪"
    }
}

// MARK: - Particle View

struct ParticleView: View {
    let particle: Particle
    let geometry: GeometryProxy

    @State private var offsetY: CGFloat = 0
    @State private var offsetX: CGFloat = 0
    @State private var opacity: Double = 0

    var body: some View {
        Group {
            if particle.isNote {
                // Musical note symbol
                Text(particle.symbol)
                    .font(.system(size: particle.size * 2))
                    .foregroundColor(.white)
            } else {
                // Simple circle
                Circle()
                    .fill(Color.white)
                    .frame(width: particle.size, height: particle.size)
            }
        }
        .position(
            x: geometry.size.width * particle.x + offsetX,
            y: geometry.size.height * particle.y + offsetY
        )
        .opacity(opacity)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Fade in
        withAnimation(.easeIn(duration: 0.5)) {
            opacity = Double.random(in: 0.05...0.15)
        }

        // Float animation
        withAnimation(
            .linear(duration: Double(20.0 / particle.speed))
            .repeatForever(autoreverses: false)
        ) {
            offsetY = geometry.size.height + 20
        }

        // Drift animation (horizontal)
        withAnimation(
            .easeInOut(duration: Double.random(in: 5...10))
            .repeatForever(autoreverses: true)
        ) {
            offsetX = CGFloat.random(in: -30...30)
        }
    }
}

// MARK: - Preview

#Preview {
    AnimatedBackgroundView()
}
