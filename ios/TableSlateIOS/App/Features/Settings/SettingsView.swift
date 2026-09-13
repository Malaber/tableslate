import SwiftUI
import TableSlateCore

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = AppearancePreference.system.rawValue
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var newPlayerName = ""

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { preference in
                        Label(preference.title, systemImage: preference.icon).tag(preference.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("appearance-picker")
            }

            Section("Interaction") {
                Toggle("Score-entry haptics", isOn: $hapticsEnabled)
            }

            Section {
                ForEach(store.data.players) { player in
                    PlayerChip(name: player.name)
                }
                .onDelete(perform: store.deletePlayers)
                HStack {
                    TextField("New player", text: $newPlayerName)
                        .textContentType(.name)
                        .onSubmit(addPlayer)
                    Button("Add", action: addPlayer)
                }
            } header: {
                Text("Players")
            } footer: {
                Text("Players remain reusable across all games. Deleting a player never changes completed score sheets.")
            }

            Section("Privacy") {
                Label("No account", systemImage: "person.crop.circle.badge.xmark")
                Label("No analytics or tracking", systemImage: "hand.raised.fill")
                Label("Scores stay on this device", systemImage: "iphone")
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                Link("Support", destination: URL(string: "https://tableslate.malaber.de/support/")!)
                Link("Privacy policy", destination: URL(string: "https://tableslate.malaber.de/privacy/")!)
            }
        }
        .scrollContentBackground(.hidden)
        .slateBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func addPlayer() {
        if store.addPlayer(name: newPlayerName) != nil { newPlayerName = "" }
    }
}
