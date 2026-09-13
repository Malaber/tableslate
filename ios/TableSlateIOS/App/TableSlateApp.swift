import SwiftUI

@main
struct TableSlateApp: App {
    @StateObject private var store = AppStore()
    @AppStorage("appearance") private var appearance = AppearancePreference.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(SlateTheme.mint)
                .preferredColorScheme(AppearancePreference(rawValue: appearance)?.colorScheme)
        }
    }
}
