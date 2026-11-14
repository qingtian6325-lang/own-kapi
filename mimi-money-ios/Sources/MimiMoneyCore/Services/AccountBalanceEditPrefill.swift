import Foundation

/// Prefill values for 账户详情 balance edit segmented control.
///
/// - 「设定期初资金」→ account `initialBalance` (0 when never set)
/// - 「校准当前余额」→ account `balance`
public enum AccountBalanceEditPrefill {
    public enum Mode: Int, Equatable, Sendable {
        case setOpening = 0
        case calibrateCurrent = 1
    }

    /// Numeric amount that should appear in the RM text field for the active segment.
    public static func amount(
        mode: Mode,
        balance: Double,
        initialBalance: Double
    ) -> Double {
        switch mode {
        case .setOpening:
            return initialBalance
        case .calibrateCurrent:
            return balance
        }
    }

    /// Text field string (`"%.2f"`) for the active segment.
    public static func formattedInput(
        mode: Mode,
        balance: Double,
        initialBalance: Double
    ) -> String {
        String(format: "%.2f", amount(mode: mode, balance: balance, initialBalance: initialBalance))
    }

    /// Empty / whitespace opening-balance field on 「添加账户」→ persist `0`.
    public static func parseNewAccountOpeningBalance(_ raw: String) -> Double {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return Double(trimmed) ?? 0
    }
}
