import SwiftUI
import MimiMoneyCore

@main
struct MimiMoneyApp: App {
    @StateObject private var store = MimiStore.shared
    @StateObject private var languageStore = AppLanguageStore.shared

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
