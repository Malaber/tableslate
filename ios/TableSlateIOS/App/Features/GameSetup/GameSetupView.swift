import SwiftUI
import TableSlateCore

struct GameSetupView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedPlayerIDs: [UUID] = []
    @State private var newPlayerName = ""
    @State private var scoringMode = 0
    @State private var highestWins = true
    @State private var didPreselect = false
    @FocusState private var newPlayerFocused: Bool

    let definition: GameDefinition
    let onStarted: (UUID) -> Void

    var body: some View {
        Form {
            Section {
                ForEach(store.data.players) { player in
                    Button { toggle(player.id) } label: {
                        HStack {
                            PlayerChip(name: player.name, selected: selectedPlayerIDs.contains(player.id))
                            Spacer()
                            if let position = selectedPlayerIDs.firstIndex(of: player.id) {
                                Text("\(position + 1)")
                                    .font(.caption.bold().monospacedDigit())
                                    .frame(width: 28, height: 28)
                                    .foregroundStyle(SlateTheme.graphite)
                                    .background(SlateTheme.mint, in: Circle())
                                    .accessibilityLabel("Player order \(position + 1)")
                            } else {
                                Image(systemName: "circle").foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("player-\(player.name)")
                }

                HStack {
                    TextField("New player", text: $newPlayerName)
                        .textContentType(.name)
                        .submitLabel(.done)
                        .focused($newPlayerFocused)
                        .onSubmit(addPlayer)
                        .accessibilityIdentifier("new-player-field")
                    Button("Add", action: addPlayer)
                        .disabled(newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                Text("Players")
            } footer: {
                Text("Choose \(definition.players.minimum)–\(definition.players.maximum). Players are saved for every future game.")
            }

            if definition.session.type == .generic {
                Section("Scoring") {
                    Picker("Mode", selection: $scoringMode) {
                        Text("Add per round").tag(0)
                        Text("Direct total").tag(1)
                    }
                    Toggle("Highest score wins", isOn: $highestWins)
                }
            }

            Section {
                PrimaryButton(title: "Start scoring", icon: "play.fill", action: start)
                    .disabled(!validPlayerCount)
                    .accessibilityIdentifier("start-scoring-button")
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .slateBackground()
        .task { preselectRecentGroup() }
    }

    private var validPlayerCount: Bool {
        (definition.players.minimum...definition.players.maximum).contains(selectedPlayerIDs.count)
    }

    private func toggle(_ id: UUID) {
        if selectedPlayerIDs.contains(id) {
            selectedPlayerIDs.removeAll { $0 == id }
        } else if selectedPlayerIDs.count < definition.players.maximum {
            selectedPlayerIDs.append(id)
        }
    }

    private func addPlayer() {
        guard let player = store.addPlayer(name: newPlayerName) else { return }
        if !selectedPlayerIDs.contains(player.id), selectedPlayerIDs.count < definition.players.maximum {
            selectedPlayerIDs.append(player.id)
        }
        newPlayerName = ""
        newPlayerFocused = false
    }

    private func start() {
        let configuration = definition.session.type == .generic
            ? ["scoringMode": scoringMode, "highestWins": highestWins ? 1 : 0]
            : [:]
        if let id = store.startSession(definition: definition, playerIDs: selectedPlayerIDs, configuration: configuration) {
            onStarted(id)
        }
    }

    private func preselectRecentGroup() {
        guard !didPreselect else { return }
        didPreselect = true
        let prior = (store.activeSessions + store.completedSessions)
            .first { $0.definitionID == definition.id }
        let validIDs = Set(store.data.players.map(\.id))
        selectedPlayerIDs = prior?.players.map(\.id).filter(validIDs.contains) ?? []
    }
}

struct PlayerChip: View {
    let name: String
    var selected = false

    var body: some View {
        HStack(spacing: 10) {
            Text(name.prefix(1).uppercased())
                .font(.caption.bold())
                .frame(width: 30, height: 30)
                .foregroundStyle(SlateTheme.graphite)
                .background(SlateTheme.mint, in: Circle())
            Text(name).font(.body.weight(selected ? .semibold : .regular))
        }
    }
}
