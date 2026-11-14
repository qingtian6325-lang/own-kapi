import SwiftUI
import MimiMoneyCore

@main
struct MimiMoneyApp: App {
    @StateObject private var store = MimiStore.shared
    /// Own the store — do not wrap `AppLanguageStore.shared` in `@StateObject`.
    @StateObject private var languageStore = AppLanguageStore()

    var body: some Scene {
        WindowGroup {
            MimiRootContainerView(store: store)
                .environmentObject(languageStore)
                .environment(\.locale, languageStore.effectiveLocale)
                // Force view tree refresh when in-app language changes.
                .id(languageStore.preference.rawValue)
                .preferredColorScheme(.light)
        }
    }
}
