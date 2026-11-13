import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

public enum MimiTheme {
    // MARK: - Light brand anchors (gold screenshots)
    public static let backgroundHex: UInt32 = 0xF5F6FA
    public static let cardHex: UInt32 = 0xFFFFFF
    public static let expenseBlueHex: UInt32 = 0x2D5AF0
    public static let incomeOrangeHex: UInt32 = 0xE8832E
    public static let balanceGreenHex: UInt32 = 0x36B37E
    public static let dangerRedHex: UInt32 = 0xEF4444
    public static let dividerHex: UInt32 = 0xE5E7EB
    public static let netWorthCardHex: UInt32 = 0xEBF1FF
    public static let assetCreamHex: UInt32 = 0xFDF9EE
    public static let textPrimaryHex: UInt32 = 0x111827
    public static let textSecondaryHex: UInt32 = 0x6B7280
    public static let textMutedHex: UInt32 = 0x9CA3AF
    public static let pillGrayHex: UInt32 = 0xF3F4F6

    // MARK: - Dark counterparts (HIG contrast, keep brand hues)
    private static let backgroundDarkHex: UInt32 = 0x0E1118
    private static let cardDarkHex: UInt32 = 0x1A1F2B
    private static let expenseBlueDarkHex: UInt32 = 0x5B7CFF
    private static let incomeOrangeDarkHex: UInt32 = 0xF0A04A
    private static let balanceGreenDarkHex: UInt32 = 0x4ADE9A
    private static let dangerRedDarkHex: UInt32 = 0xF87171
    private static let dividerDarkHex: UInt32 = 0x2E3444
    private static let netWorthCardDarkHex: UInt32 = 0x1B2438
    private static let assetCreamDarkHex: UInt32 = 0x2A2418
    private static let textPrimaryDarkHex: UInt32 = 0xF3F4F6
    private static let textSecondaryDarkHex: UInt32 = 0xA1A8B7
    private static let textMutedDarkHex: UInt32 = 0x7B8496
    private static let pillGrayDarkHex: UInt32 = 0x262B38
    private static let fillSubtleDarkHex: UInt32 = 0x222734
    private static let strokeSubtleDarkHex: UInt32 = 0x3A4154
    private static let tintBlueSoftDarkHex: UInt32 = 0x243056

    public static var background: Color { Color(lightHex: backgroundHex, darkHex: backgroundDarkHex) }
    public static var cardBackground: Color { Color(lightHex: cardHex, darkHex: cardDarkHex) }
    public static var expenseBlue: Color { Color(lightHex: expenseBlueHex, darkHex: expenseBlueDarkHex) }
    public static var incomeOrange: Color { Color(lightHex: incomeOrangeHex, darkHex: incomeOrangeDarkHex) }
    public static var balanceGreen: Color { Color(lightHex: balanceGreenHex, darkHex: balanceGreenDarkHex) }
    public static var dangerRed: Color { Color(lightHex: dangerRedHex, darkHex: dangerRedDarkHex) }
    public static var divider: Color { Color(lightHex: dividerHex, darkHex: dividerDarkHex) }
    public static var netWorthCard: Color { Color(lightHex: netWorthCardHex, darkHex: netWorthCardDarkHex) }
    public static var assetCream: Color { Color(lightHex: assetCreamHex, darkHex: assetCreamDarkHex) }
    public static var textPrimary: Color { Color(lightHex: textPrimaryHex, darkHex: textPrimaryDarkHex) }
    public static var textSecondary: Color { Color(lightHex: textSecondaryHex, darkHex: textSecondaryDarkHex) }
    public static var textMuted: Color { Color(lightHex: textMutedHex, darkHex: textMutedDarkHex) }
    public static var pillGray: Color { Color(lightHex: pillGrayHex, darkHex: pillGrayDarkHex) }

    /// Secondary fills (chips, keypad wells, input capsules).
    public static var fillSubtle: Color { Color(lightHex: 0xF2F4F8, darkHex: fillSubtleDarkHex) }
    /// Hairline strokes / inactive borders.
    public static var strokeSubtle: Color { Color(lightHex: 0xD5DAE6, darkHex: strokeSubtleDarkHex) }
    /// Soft blue tint (user bubbles, AI chips).
    public static var tintBlueSoft: Color { Color(lightHex: 0xE8EEFF, darkHex: tintBlueSoftDarkHex) }
    public static var tintBlueChip: Color { Color(lightHex: 0xE8F0FE, darkHex: tintBlueSoftDarkHex) }
    public static var scrim: Color { Color(light: Color.black.opacity(0.28), dark: Color.black.opacity(0.55)) }

    // MARK: - Home layout tokens (gold screenshot A)
    public static let homeHorizontalPadding: CGFloat = 16
    public static let homeCardSpacing: CGFloat = 14
    public static let cardCornerRadius: CGFloat = 18
    public static let askBarHeight: CGFloat = 56
    public static let askBarCornerRadius: CGFloat = 25
    public static let transactionRowIconSize: CGFloat = 38
    public static let progressBarHeight: CGFloat = 18
    public static let dailyRingSize: CGFloat = 72

    public static var homeCardShadow: Color {
        Color(light: Color.black.opacity(0.06), dark: Color.black.opacity(0.45))
    }
    public static let homeCardShadowRadius: CGFloat = 10
    public static let homeCardShadowY: CGFloat = 3

    // MARK: - Drawer layout tokens (gold screenshot D0)
    public static let drawerWidthFraction: CGFloat = 0.82
    public static let drawerContentPadding: CGFloat = 18
    public static let drawerSectionSpacing: CGFloat = 18
    public static let drawerGridIconSize: CGFloat = 48
    public static let drawerGridIconCorner: CGFloat = 14
    public static let drawerAvatarSize: CGFloat = 48
    public static let drawerHeatmapCellHeight: CGFloat = 22
    public static let proBadgeBlueHex: UInt32 = 0x2D5AF0
    public static let vipGoldHex: UInt32 = 0xE6A23C
    public static var proBadgeBlue: Color { expenseBlue }
    public static var vipGold: Color { Color(lightHex: vipGoldHex, darkHex: 0xF0C56C) }

    // MARK: - Calendar layout tokens (gold C0)
    public static let calendarHorizontalPadding: CGFloat = 16
    public static let calendarDayCellHeight: CGFloat = 52
    public static let calendarCardCorner: CGFloat = 18

    // MARK: - Dynamic Type fonts

    /// Scaled system font; updates with `@Environment(\.sizeCategory)`.
    public static func font(
        size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .system(size: scaledSize(size, relativeTo: textStyle), weight: weight, design: design)
    }

    public static func scaledSize(_ size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> CGFloat {
        #if canImport(UIKit)
        let uiStyle = uiTextStyle(textStyle)
        return UIFontMetrics(forTextStyle: uiStyle).scaledValue(for: size)
        #else
        return size
        #endif
    }

    #if canImport(UIKit)
    private static func uiTextStyle(_ style: Font.TextStyle) -> UIFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .body: return .body
        case .callout: return .callout
        case .subheadline: return .subheadline
        case .footnote: return .footnote
        case .caption: return .caption1
        case .caption2: return .caption2
        @unknown default: return .body
        }
    }
    #endif

    public static func formatRM(_ value: Double) -> String {
        formatAmount(value, currency: .myr, signed: false)
    }

    public static func formatAmount(_ value: Double, currency: CurrencyCode = .myr, signed: Bool = false, isExpense: Bool = true) -> String {
        let absVal = abs(value)
        let formatted = String(format: "%.2f", absVal)
        let parts = formatted.split(separator: ".")
        let intPart = Int(parts[0]) ?? 0
        let decPart = parts.count > 1 ? String(parts[1]) : "00"
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        let groupedInt = numberFormatter.string(from: NSNumber(value: intPart)) ?? "\(intPart)"
        let base = "\(currency.symbol)\(groupedInt).\(decPart)"
        if signed {
            return isExpense ? "-\(base)" : "+\(base)"
        }
        if value < -0.0001 {
            return "-\(base)"
        }
        return base
    }
}

public extension Color {
    /// Fixed sRGB color (stickers / brand glyphs that should not invert).
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    init(lightHex: UInt32, darkHex: UInt32, alpha: Double = 1.0) {
        self.init(light: Color(hex: lightHex, alpha: alpha), dark: Color(hex: darkHex, alpha: alpha))
    }

    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark)
                : NSColor(light)
        }))
        #else
        self = light
        #endif
    }
}

public struct MimiScaledFontModifier: ViewModifier {
    @Environment(\.sizeCategory) private var sizeCategory

    var size: CGFloat
    var weight: Font.Weight
    var design: Font.Design
    var relativeTo: Font.TextStyle

    public func body(content: Content) -> some View {
        let _ = sizeCategory
        content.font(MimiTheme.font(size: size, weight: weight, design: design, relativeTo: relativeTo))
    }
}

public extension View {
    /// Dynamic Type–aware system font (HIG). Prefer this over `.font(.system(size:))`.
    func mimiFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(MimiScaledFontModifier(size: size, weight: weight, design: design, relativeTo: textStyle))
    }
}
