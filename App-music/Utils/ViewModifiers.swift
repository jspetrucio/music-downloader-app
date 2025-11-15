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
// Apple-inspired minimalist design system

struct DesignTokens {
    // MARK: - Background Colors (Pure Black + Subtle Variations)
    /// Pure black background - main app background
    static let backgroundPrimary = Color(hex: "#000000")
    /// Very dark gray - subtle variation
    static let backgroundSecondary = Color(hex: "#0A0A0A")
    /// Dark gray - tertiary background
    static let backgroundTertiary = Color(hex: "#1A1A1A")

    // MARK: - Glassmorphism Colors
    /// Glass background - ultra subtle white overlay
    static let glassBackground = Color.white.opacity(0.05)
    /// Glass border - subtle white border
    static let glassBorder = Color.white.opacity(0.1)
    /// Glass hover state
    static let glassHover = Color.white.opacity(0.08)

    // MARK: - Accent Color (Purple/Violet - vibrant and modern)
    /// Primary accent - Purple for active states and CTAs
    static let accentPrimary = Color(hex: "#8B5CF6")
    /// Secondary accent - Lighter purple for highlights
    static let accentSecondary = Color(hex: "#A78BFA")
    /// Tertiary accent - Darker purple for depth
    static let accentTertiary = Color(hex: "#7C3AED")

    // MARK: - Text Colors (High Contrast)
    /// Primary text - pure white for main content
    static let textPrimary = Color.white
    /// Secondary text - gray for supporting content
    static let textSecondary = Color(hex: "#8E8E93")
    /// Tertiary text - darker gray for less important content
    static let textTertiary = Color(hex: "#48484A")

    // MARK: - Status Colors
    static let success = Color(hex: "#34C759")
    static let error = Color(hex: "#FF3B30")
    static let warning = Color(hex: "#FF9500")

    // MARK: - Gradient Colors (Subtle Dark Gradients)
    static let gradientStart = Color(hex: "#000000")
    static let gradientMid1 = Color(hex: "#0A0A0A")
    static let gradientMid2 = Color(hex: "#1A1A1A")
    static let gradientEnd = Color(hex: "#0A0A0A")

    // MARK: - Dimensions
    static let miniPlayerHeight: CGFloat = 64
    static let progressBarHeight: CGFloat = 6
    /// Small radius for compact elements
    static let cornerRadiusSmall: CGFloat = 12
    /// Medium radius for cards
    static let cornerRadiusMedium: CGFloat = 16
    /// Large radius for prominent elements
    static let cornerRadiusLarge: CGFloat = 24
    /// Extra large radius for pills/buttons
    static let cornerRadiusXL: CGFloat = 32
    /// Default corner radius
    static let cornerRadius: CGFloat = 16

    // MARK: - Spacing (8pt grid)
    static let spacingXS: CGFloat = 8
    static let spacingSM: CGFloat = 16
    static let spacingMD: CGFloat = 24
    static let spacingLG: CGFloat = 32
    static let spacingXL: CGFloat = 48
    static let spacing2XL: CGFloat = 64
    static let spacing: CGFloat = 16

    // MARK: - Animation Durations
    static let animationFast: Double = 0.2
    static let animationMedium: Double = 0.3
    static let animationSlow: Double = 0.4

    // MARK: - Blur Radius
    static let blurLight: CGFloat = 10
    static let blurMedium: CGFloat = 20
    static let blurHeavy: CGFloat = 30
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

// MARK: - Glassmorphism Modifier

struct GlassmorphismModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignTokens.cornerRadiusLarge
    var blurRadius: CGFloat = DesignTokens.blurMedium

    func body(content: Content) -> some View {
        content
            .background(
                DesignTokens.glassBackground
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(DesignTokens.glassBorder, lineWidth: 1)
                    )
                    .blur(radius: 0.5) // Slight blur for smoothness
            )
            .background(.ultraThinMaterial.opacity(0.5))
            .cornerRadius(cornerRadius)
    }
}

extension View {
    /// Apply glassmorphism effect
    func glassmorphism(cornerRadius: CGFloat = DesignTokens.cornerRadiusLarge, blur: CGFloat = DesignTokens.blurMedium) -> some View {
        modifier(GlassmorphismModifier(cornerRadius: cornerRadius, blurRadius: blur))
    }
}

// MARK: - Minimalist Card Style

struct MinimalistCardModifier: ViewModifier {
    var cornerRadius: CGFloat = DesignTokens.cornerRadiusLarge
    var padding: CGFloat = DesignTokens.spacingMD

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DesignTokens.glassBackground)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DesignTokens.glassBorder, lineWidth: 1)
            )
            .cornerRadius(cornerRadius)
    }
}

extension View {
    /// Apply minimalist card style with glass effect
    func minimalistCard(cornerRadius: CGFloat = DesignTokens.cornerRadiusLarge, padding: CGFloat = DesignTokens.spacingMD) -> some View {
        modifier(MinimalistCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Outline Button Style

struct OutlineButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = DesignTokens.cornerRadiusXL
    var borderColor: Color = .white
    var borderWidth: CGFloat = 1.5

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, DesignTokens.spacingMD)
            .padding(.vertical, DesignTokens.spacingSM)
            .background(
                configuration.isPressed
                    ? DesignTokens.glassHover
                    : DesignTokens.glassBackground
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .cornerRadius(cornerRadius)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    /// Apply outline button style
    func outlineButtonStyle(cornerRadius: CGFloat = DesignTokens.cornerRadiusXL, borderColor: Color = .white) -> some View {
        buttonStyle(OutlineButtonStyle(cornerRadius: cornerRadius, borderColor: borderColor))
    }
}
