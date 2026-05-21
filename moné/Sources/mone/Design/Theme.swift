import SwiftUI

// MARK: - Color Palette
// "Moné Design System" — Financial Noir
// Pure black base · charcoal card surfaces · 1 pt #2A2A2A hairlines
// Primary text warm off-white · action fill soft warm white

extension Color {
    // ── Backgrounds ────────────────────────────────────────────────────────
    static let moneBackground    = Color(hex: "141313")   // near-pure black base
    static let moneSurfaceLow    = Color(hex: "0E0E0E")   // surface-container-lowest
    static let moneSurface       = Color(hex: "1C1B1B")   // card fill (surface-container-low)
    static let moneSurfaceEl     = Color(hex: "252422")   // elevated card / modal surface
    static let moneSurfaceHigh   = Color(hex: "2E2C2A")   // highest elevation (menus, tooltips)

    // ── Borders / Strokes ──────────────────────────────────────────────────
    static let moneStroke        = Color(hex: "2A2A2A")   // 1 pt solid — primary hairline
    static let moneStrokeMid     = Color(hex: "3A3937")   // mid-emphasis dividers
    static let moneStrokeBright  = Color(hex: "504E4C")   // interactive borders on hover

    // ── Text ───────────────────────────────────────────────────────────────
    static let monePrimary       = Color(hex: "E5E2E0")   // on-surface (warm off-white)
    static let moneSecondary     = Color(hex: "C8C7BE")   // on-surface-variant
    static let moneTertiary      = Color(hex: "6B6B62")   // disabled / placeholder
    static let moneInverse       = Color(hex: "141313")   // text on light action buttons

    // ── Semantic ────────────────────────────────────────────────────────────
    // Deliberately muted & desaturated — Financial Noir avoids loud chroma
    static let moneHealthy       = Color(hex: "4D8C5F")   // forest green (healthy state)
    static let moneHealthyBg     = Color(hex: "4D8C5F").opacity(0.10)
    static let moneWatch         = Color(hex: "9C8440")   // amber (watch state)
    static let moneWatchBg       = Color(hex: "9C8440").opacity(0.10)
    static let moneRisk          = Color(hex: "9E4545")   // crimson (risk state)
    static let moneRiskBg        = Color(hex: "9E4545").opacity(0.10)
    static let moneInfo          = Color(hex: "5A6E8C")   // slate blue (informational)
    static let moneCelebration   = Color(hex: "C4A35A")   // warm gold (milestone / celebration)

    // ── Primary Action ─────────────────────────────────────────────────────
    static let moneActionFill    = Color(hex: "F4F1EA")   // soft warm white pill background
    static let moneActionFg      = Color(hex: "141313")   // near-black text on pill

    // ── Hex initialiser ────────────────────────────────────────────────────
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 255, 255, 255)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Semantic Color from HealthStatus

extension HealthStatus {
    var color: Color {
        switch self {
        case .healthy: return .moneHealthy
        case .watch:   return .moneWatch
        case .risk:    return .moneRisk
        }
    }
    var bgColor: Color {
        switch self {
        case .healthy: return .moneHealthyBg
        case .watch:   return .moneWatchBg
        case .risk:    return .moneRiskBg
        }
    }
}

// MARK: - Typography Scale
// Display / Headline → .design: .serif   (Financial Noir: Playfair Display)
// Body / UI copy    → .design: .default  (Financial Noir: Hanken Grotesk)
// Amounts / Figures → .design: .monospaced (Financial Noir: JetBrains Mono)

extension Font {
    // Display (hero amounts, onboarding splash)
    static let moneDisplay   = Font.system(size: 40, weight: .bold,     design: .serif)
    static let moneDisplayMd = Font.system(size: 32, weight: .bold,     design: .serif)

    // Headlines
    static let moneHL        = Font.system(size: 24, weight: .semibold, design: .serif)
    static let moneHLMd      = Font.system(size: 20, weight: .semibold, design: .serif)
    static let moneHLSm      = Font.system(size: 17, weight: .semibold).monospacedDigit()

    // Financial amounts — monospaced for tabular alignment (JetBrains Mono analog)
    static let moneAmtLg     = Font.system(size: 34, weight: .semibold, design: .monospaced)
    static let moneAmtMd     = Font.system(size: 22, weight: .medium,   design: .monospaced)
    static let moneAmtSm     = Font.system(size: 17, weight: .medium,   design: .monospaced)

    // Body (Hanken Grotesk analog — default system is clean sans-serif)
    static let moneBodyLg    = Font.system(size: 17, weight: .regular).monospacedDigit()
    static let moneBodyMd    = Font.system(size: 15, weight: .regular).monospacedDigit()
    static let moneBodySm    = Font.system(size: 13, weight: .regular).monospacedDigit()

    // Labels / Caps
    static let moneLabelCaps = Font.system(size: 11, weight: .bold).monospacedDigit()
    static let moneCaption   = Font.system(size: 12, weight: .regular).monospacedDigit()
}

// MARK: - Spacing Tokens

enum MoneSpacing {
    static let page:    CGFloat = 20
    static let gutter:  CGFloat = 16
    static let cardLg:  CGFloat = 24
    static let cardSm:  CGFloat = 16
    static let gap:     CGFloat = 8
    static let section: CGFloat = 32
}

// MARK: - Corner Radius Tokens

enum MoneRadius {
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 24
    static let pill: CGFloat = 999
}

// MARK: - View Modifiers

struct MoneCardModifier: ViewModifier {
    var radius:   CGFloat = MoneRadius.xxl
    var elevated: Bool    = false

    func body(content: Content) -> some View {
        content
            .background(elevated ? Color.moneSurfaceEl : Color.moneSurface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(elevated ? Color.moneStrokeMid : Color.moneStroke, lineWidth: elevated ? 0.5 : 1)
            )
    }
}

extension View {
    func moneCard(radius: CGFloat = MoneRadius.xxl, elevated: Bool = false) -> some View {
        modifier(MoneCardModifier(radius: radius, elevated: elevated))
    }

    func moneLabelCaps(color: Color = .moneSecondary) -> some View {
        self
            .font(.moneLabelCaps)
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

// MARK: - Contour / Orbital Background Pattern
// Very faint arcs — kept at ultra-low opacity to complement the noir black canvas

struct ContourBackground: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .strokeBorder(Color.white.opacity(0.018 - Double(i) * 0.004), lineWidth: 1)
                        .frame(width:  geo.size.width * (1.2 + Double(i) * 0.5),
                               height: geo.size.width * (1.2 + Double(i) * 0.5))
                        .offset(x: geo.size.width * 0.3, y: -geo.size.height * 0.1)
                }
            }
        }
        .clipped()
    }
}
