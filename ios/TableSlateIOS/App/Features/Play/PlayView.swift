import SwiftUI
import TableSlateCore

struct PlayView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var showingSettings: Bool
    @State private var path: [UUID] = []
    @State private var showingStart = false
    @State private var initialDefinition: GameDefinition?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    hero
                    if !store.activeSessions.isEmpty { activeGames }
                    if !favoriteDefinitions.isEmpty { favorites }
                    if !recentDefinitions.isEmpty { recentGames }
                    if store.activeSessions.isEmpty && recentDefinitions.isEmpty {
                        EmptyState(
                            icon: "tablecells",
                            title: "Ready for game night",
                            message: "Create your players once, then keep every score sheet close at hand."
                        )
                        .frame(minHeight: 250)
                    }
                }
                .padding()
                .padding(.bottom, 24)
            }
            .slateBackground()
            .navigationTitle("TableSlate")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton(showingSettings: $showingSettings)
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Start Game", icon: "play.fill") { beginStart() }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .accessibilityIdentifier("start-game-button")
            }
            .navigationDestination(for: UUID.self) { sessionID in
                ActiveSessionView(sessionID: sessionID)
            }
            .sheet(isPresented: $showingStart) {
                StartGameFlow(initialDefinition: initialDefinition) { sessionID in
                    showingStart = false
                    Task { @MainActor in path.append(sessionID) }
                }
                .environmentObject(store)
            }
        }
    }

    private var hero: some View {
        SlateCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Less bookkeeping. More playing.")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.primary)
                Text("Fast, offline score keeping for every table.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Label("Offline", systemImage: "wifi.slash")
                    Label("Auto-saved", systemImage: "checkmark.circle")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(SlateTheme.deepMint)
                .padding(.top, 4)
            }
        }
    }

    private var activeGames: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Resume", subtitle: "Every change is already saved")
            ForEach(store.activeSessions) { session in
                NavigationLink(value: session.id) {
                    SlateCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(session.definitionSnapshot.name).font(.headline)
                                Text(session.players.map(\.name).joined(separator: " · "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if session.definitionSnapshot.session.type == .roundBased {
                                    Text("Round \(session.currentRound)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(SlateTheme.deepMint)
                                }
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(SlateTheme.mint)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("resume-\(session.definitionID)")
            }
        }
    }

    private var favorites: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Favorites")
            ForEach(favoriteDefinitions) { definition in
                Button { beginStart(with: definition) } label: {
                    GameCard(definition: definition, favorite: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentGames: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Recent games")
            ForEach(recentDefinitions) { definition in
                Button { beginStart(with: definition) } label: {
                    GameCard(definition: definition, favorite: store.data.favoriteGameIDs.contains(definition.id))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var favoriteDefinitions: [GameDefinition] {
        store.allDefinitions.filter { store.data.favoriteGameIDs.contains($0.id) }
    }

    private var recentDefinitions: [GameDefinition] {
        store.data.recentGameIDs.compactMap(store.definition(id:))
    }

    private func beginStart(with definition: GameDefinition? = nil) {
        initialDefinition = definition
        showingStart = true
    }
}

private struct StartGameFlow: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDefinition: GameDefinition?
    let onStarted: (UUID) -> Void

    init(initialDefinition: GameDefinition? = nil, onStarted: @escaping (UUID) -> Void) {
        _selectedDefinition = State(initialValue: initialDefinition)
        self.onStarted = onStarted
    }

    var body: some View {
        NavigationStack {
            Group {
                if let definition = selectedDefinition {
                    GameSetupView(definition: definition, onStarted: onStarted)
                } else {
                    List(store.allDefinitions) { definition in
                        Button { selectedDefinition = definition } label: {
                            GameCard(
                                definition: definition,
                                favorite: store.data.favoriteGameIDs.contains(definition.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("choose-game-\(definition.id)")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .overlay {
                        if store.allDefinitions.isEmpty {
                            EmptyState(icon: "exclamationmark.triangle", title: "Games unavailable", message: "Built-in definitions could not be loaded.")
                        }
                    }
                }
            }
            .navigationTitle(selectedDefinition?.name ?? "Choose a game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if selectedDefinition == nil {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button { selectedDefinition = nil } label: { Label("Games", systemImage: "chevron.left") }
                    }
                }
            }
        }
    }
}
