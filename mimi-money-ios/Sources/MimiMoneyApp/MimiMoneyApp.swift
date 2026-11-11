import SwiftUI
import MimiMoneyCore

@main
struct MimiMoneyApp: App {
    @StateObject private var store = MimiStore.shared

    var body: some Scene {
        WindowGroup {
            MimiRootContainerView(store: store)
                .preferredColorScheme(.light)
        }
    }
}
