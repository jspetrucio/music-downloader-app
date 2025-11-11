import SwiftUI

// MARK: - Color Extensions

extension Color {
    /// Initialize Color from hex string
    /// - Parameter hex: Hex string (with or without #)
    /// - Example: Color(hex: "#1A1A2E") or Color(hex: "1A1A2E")
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Design Tokens

struct DesignTokens {
    // Background Colors
    static let backgroundPrimary = Color(hex: "#0A0A0A")
    static let backgroundSecondary = Color(hex: "#1A1A2E")
    static let backgroundTertiary = Color(hex: "#16213E")

    // Accent Colors
    static let accentPrimary = Color(hex: "#E94560")
    static let accentSecondary = Color(hex: "#0F3460")

    // Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#B8B8B8")
    static let textTertiary = Color(hex: "#808080")

    // Status Colors
    static let success = Color(hex: "#4CAF50")
    static let error = Color(hex: "#F44336")
    static let warning = Color(hex: "#FF9800")

    // Gradient Colors
    static let gradientStart = Color(hex: "#0A0A0A")
    static let gradientMid1 = Color(hex: "#1A1A2E")
    static let gradientMid2 = Color(hex: "#16213E")
    static let gradientEnd = Color(hex: "#0F3460")

    // Dimensions
    static let miniPlayerHeight: CGFloat = 64
    static let progressBarHeight: CGFloat = 6
    static let cornerRadius: CGFloat = 12
    static let spacing: CGFloat = 16

    // Animation Durations
    static let animationFast: Double = 0.2
    static let animationMedium: Double = 0.3
    static let animationSlow: Double = 0.4
}

// MARK: - Download Background Modifier

struct DownloadBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: DesignTokens.gradientStart, location: 0.0),
                        .init(color: DesignTokens.gradientMid1, location: 0.3),
                        .init(color: DesignTokens.gradientMid2, location: 0.6),
                        .init(color: DesignTokens.gradientEnd, location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
    }
}

extension View {
    /// Apply the download screen gradient background
    func downloadBackground() -> some View {
        modifier(DownloadBackgroundModifier())
    }
}

// MARK: - Custom Progress Bar Style

struct CustomProgressViewStyle: ProgressViewStyle {
    var tint: Color = DesignTokens.accentPrimary
    var height: CGFloat = DesignTokens.progressBarHeight

    func makeBody(configuration: Configuration) -> some View {
        let progress = configuration.fractionCompleted ?? 0.0

        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: height)

                // Progress fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [tint, tint.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: height)
                    .animation(.easeInOut(duration: DesignTokens.animationMedium), value: progress)
            }
        }
        .frame(height: height)
    }
}

extension View {
    /// Apply custom progress bar style
    func customProgressStyle(tint: Color = DesignTokens.accentPrimary, height: CGFloat = DesignTokens.progressBarHeight) -> some View {
        progressViewStyle(CustomProgressViewStyle(tint: tint, height: height))
    }
}

// MARK: - Card Style Modifier

struct CardStyle: ViewModifier {
    var backgroundColor: Color = DesignTokens.backgroundSecondary

    func body(content: Content) -> some View {
        content
            .padding()
            .background(backgroundColor)
            .cornerRadius(DesignTokens.cornerRadius)
            .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

extension View {
    /// Apply card style
    func cardStyle(backgroundColor: Color = DesignTokens.backgroundSecondary) -> some View {
        modifier(CardStyle(backgroundColor: backgroundColor))
    }
}

// MARK: - Pulse Animation

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    var minScale: CGFloat = 0.95
    var maxScale: CGFloat = 1.05
    var duration: Double = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? maxScale : minScale)
            .animation(
                .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    /// Add pulse animation
    func pulse(minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05, duration: Double = 1.0) -> some View {
        modifier(PulseModifier(minScale: minScale, maxScale: maxScale, duration: duration))
    }
}
