import Foundation
import CoreGraphics

/// Axis policy for 支出|收入|转账 paging inside a dismissible sheet.
/// Horizontal-dominant drags must switch tabs; only clearly vertical drags dismiss.
public enum BookkeepingSheetSwipePolicy {
    public static let tabOrder: [TransactionType] = [.expense, .income, .transfer]

    /// Prefer horizontal when |dx| clearly exceeds |dy| (avoids diagonal sheet dismiss steal).
    public static func isHorizontalDominant(
        dx: CGFloat,
        dy: CGFloat,
        ratio: CGFloat = 1.25,
        minDistance: CGFloat = 12
    ) -> Bool {
        let ax = abs(dx)
        let ay = abs(dy)
        guard ax >= minDistance || ay >= minDistance else { return false }
        return ax > ay * ratio
    }

    public static func isVerticalDominant(
        dx: CGFloat,
        dy: CGFloat,
        ratio: CGFloat = 1.25,
        minDistance: CGFloat = 12
    ) -> Bool {
        let ax = abs(dx)
        let ay = abs(dy)
        guard ax >= minDistance || ay >= minDistance else { return false }
        return ay > ax * ratio
    }

    public static func index(of tab: TransactionType) -> Int {
        tabOrder.firstIndex(of: tab) ?? 0
    }

    public static func tab(at index: Int) -> TransactionType {
        let clamped = min(max(0, index), tabOrder.count - 1)
        return tabOrder[clamped]
    }

    /// - Parameters:
    ///   - dx: drag translation width (negative = swipe left → next tab).
    public static func neighbor(of tab: TransactionType, dx: CGFloat, threshold: CGFloat = 48) -> TransactionType? {
        guard abs(dx) >= threshold else { return nil }
        let idx = index(of: tab)
        if dx < 0, idx + 1 < tabOrder.count {
            return tabOrder[idx + 1]
        }
        if dx > 0, idx - 1 >= 0 {
            return tabOrder[idx - 1]
        }
        return nil
    }
}
