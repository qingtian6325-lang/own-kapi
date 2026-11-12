import SwiftUI

public enum MimiTheme {
    // Exact Mimi Money color tokens from IMG_2240 - IMG_2294
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

    public static var background: Color { Color(hex: backgroundHex) }
    public static var cardBackground: Color { Color(hex: cardHex) }
    public static var expenseBlue: Color { Color(hex: expenseBlueHex) }
    public static var incomeOrange: Color { Color(hex: incomeOrangeHex) }
    public static var balanceGreen: Color { Color(hex: balanceGreenHex) }
    public static var dangerRed: Color { Color(hex: dangerRedHex) }
    public static var divider: Color { Color(hex: dividerHex) }
    public static var netWorthCard: Color { Color(hex: netWorthCardHex) }
    public static var assetCream: Color { Color(hex: assetCreamHex) }
    public static var textPrimary: Color { Color(hex: textPrimaryHex) }
    public static var textSecondary: Color { Color(hex: textSecondaryHex) }
    public static var textMuted: Color { Color(hex: textMutedHex) }
    public static var pillGray: Color { Color(hex: pillGrayHex) }

    // MARK: - Home layout tokens (gold screenshot A)
    public static let homeHorizontalPadding: CGFloat = 16
    public static let homeCardSpacing: CGFloat = 14
    public static let cardCornerRadius: CGFloat = 18
    public static let askBarHeight: CGFloat = 50
    public static let askBarCornerRadius: CGFloat = 25
    public static let transactionRowIconSize: CGFloat = 38
    public static let progressBarHeight: CGFloat = 18
    public static let dailyRingSize: CGFloat = 72

    public static var homeCardShadow: Color { Color.black.opacity(0.06) }
    public static let homeCardShadowRadius: CGFloat = 10
    public static let homeCardShadowY: CGFloat = 3

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
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
