import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @AppStorage("selectedTab") private var selectedTab = 0
    @State private var showingSettings = false

    var body: some View {
        TabView(selection: $selectedTab) {
            PlayView(showingSettings: $showingSettings)
                .tabItem { Label("Play", systemImage: "play.fill") }
                .tag(0)
            GamesView(showingSettings: $showingSettings)
                .tabItem { Label("Games", systemImage: "square.grid.2x2.fill") }
                .tag(1)
            HistoryView(showingSettings: $showingSettings)
                .tabItem { Label("History", systemImage: "clock.fill") }
                .tag(2)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
        .alert(item: $store.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
    }
}
