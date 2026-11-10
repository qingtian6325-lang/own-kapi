import Foundation

public enum KeypadCalculator {
    /// Evaluates chained `+` and `-` expressions entered on the custom bookkeeping keypad (e.g. "15.5+4.5-2" -> 18.0).
    /// Clamps negative totals to 0.0 and ignores trailing operators ("38.78+" -> 38.78).
    public static func evaluate(_ expression: String) -> Double {
        let cleaned = expression
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "RM", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "$", with: "")
        guard !cleaned.isEmpty else { return 0.0 }

        var total: Double = 0.0
        var currentNumberString = ""
        var currentOperator: Character = "+"

        func flushToken() {
            guard !currentNumberString.isEmpty else { return }
            let val = Double(currentNumberString) ?? 0.0
            if currentOperator == "+" {
                total += val
            } else if currentOperator == "-" {
                total -= val
            }
            currentNumberString = ""
        }

        for ch in cleaned {
            if ch == "+" || ch == "-" {
                flushToken()
                currentOperator = ch
            } else if ch.isNumber || ch == "." {
                if ch == "." && currentNumberString.contains(".") {
                    continue
                }
                currentNumberString.append(ch)
            }
        }
        flushToken()

        return max(0.0, (total * 100.0).rounded() / 100.0)
    }
}
