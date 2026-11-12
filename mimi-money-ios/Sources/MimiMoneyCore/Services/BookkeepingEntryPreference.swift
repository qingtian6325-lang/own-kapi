import Foundation

/// 记住用户上次用 AI 记账还是手动记账，下次默认走同一入口。
public enum BookkeepingEntryMode: String, Sendable {
    case ai
    case manual
}

public enum BookkeepingEntryPreference {
    private static let key = "mimi_bookkeeping_entry_mode"

    public static var current: BookkeepingEntryMode {
        get {
            if let raw = UserDefaults.standard.string(forKey: key),
               let mode = BookkeepingEntryMode(rawValue: raw) {
                return mode
            }
            return .ai
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    public static func rememberAI() { current = .ai }
    public static func rememberManual() { current = .manual }
}
