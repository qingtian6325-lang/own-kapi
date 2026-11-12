import Foundation
#if canImport(Security)
import Security
#endif

// MARK: - Provider（识别 + 问账共用）

public enum AIEngineProvider: String, CaseIterable, Identifiable, Sendable {
    case gemini
    case groq

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .gemini: return "Gemini"
        case .groq: return "Groq"
        }
    }

    public var supportsImageInput: Bool { true }

    public var keyApplyHint: String {
        switch self {
        case .gemini: return "在 aistudio.google.com 免费申请"
        case .groq: return "在 console.groq.com 免费申请"
        }
    }
}

public enum AIEngineSettings {
    private static let providerKey = "mimi_ai_engine_provider"

    /// 当前试用阶段默认走 Groq（识图用 qwen/qwen3.8-27b）；需要时可改回 gemini。
    public static var provider: AIEngineProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: providerKey) ?? AIEngineProvider.groq.rawValue
            return AIEngineProvider(rawValue: raw) ?? .groq
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: providerKey)
        }
    }

    public static var hasAPIKey: Bool {
        switch provider {
        case .gemini: return GeminiSettings.hasAPIKey
        case .groq: return GroqSettings.hasAPIKey
        }
    }

    public static var lastCallStatusText: String? {
        switch provider {
        case .gemini: return GeminiSettings.lastCallStatusText
        case .groq: return GroqSettings.lastCallStatusText
        }
    }

    public static func recordCallStatus(success: Bool, message: String) {
        switch provider {
        case .gemini: GeminiSettings.recordCallStatus(success: success, message: message)
        case .groq: GroqSettings.recordCallStatus(success: success, message: message)
        }
    }
}

// MARK: - Keychain（多账户：Gemini / Groq）

public enum MimiKeychain {
    public static func save(service: String, account: String, value: String?) {
        #if canImport(Security)
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
        #endif
    }

    public static func read(service: String, account: String) -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        return nil
        #endif
    }
}
