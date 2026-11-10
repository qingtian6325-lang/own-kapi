import SwiftUI
import KapiMoneyCore

@main
struct KapiMoneyApp: App {
    @StateObject private var store = KapiStore.shared

    var body: some Scene {
        WindowGroup {
            KapiRootContainerView(store: store)
                .preferredColorScheme(.light)
        }
    }
}
