import SwiftUI
import TableSlateCore
import UniformTypeIdentifiers

struct GamesView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var showingSettings: Bool
    @State private var query = ""
    @State private var showingImporter = false
    @State private var pendingImport: GameDefinition?

    var body: some View {
        NavigationStack {
            List {
                if !favorites.isEmpty {
                    Section("Favorites") {
                        definitionRows(favorites)
                    }
                }
                Section("All games") {
                    definitionRows(filteredDefinitions)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .slateBackground()
            .navigationTitle("Games")
            .searchable(text: $query, prompt: "Search games")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button { showingImporter = true } label: {
                            Label("Import Game Definition", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Game actions")
                    SettingsToolbarButton(showingSettings: $showingSettings)
                }
            }
            .overlay {
                if filteredDefinitions.isEmpty {
                    EmptyState(icon: "magnifyingglass", title: "No games found", message: "Try another name or import a definition.")
                }
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result {
                    pendingImport = store.prepareDefinitionImport(from: url)
                }
                if case .failure(let error) = result {
                    store.notice = AppNotice(title: "Couldn’t open definition", message: error.localizedDescription)
                }
            }
            .sheet(item: $pendingImport) { definition in
                ImportDefinitionPreview(
                    definition: definition,
                    isUpdate: store.isDefinitionUpdate(definition),
                    onCancel: { pendingImport = nil },
                    onConfirm: {
                        store.installImportedDefinition(definition)
                        pendingImport = nil
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func definitionRows(_ definitions: [GameDefinition]) -> some View {
        ForEach(definitions) { definition in
            NavigationLink {
                GameDetailView(definition: definition)
            } label: {
                GameCard(definition: definition, favorite: store.data.favoriteGameIDs.contains(definition.id))
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private var filteredDefinitions: [GameDefinition] {
        guard !query.isEmpty else { return store.allDefinitions }
        return store.allDefinitions.filter { definition in
            ([definition.name] + definition.aliases).contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    private var favorites: [GameDefinition] {
        filteredDefinitions.filter { store.data.favoriteGameIDs.contains($0.id) }
    }
}

private struct ImportDefinitionPreview: View {
    let definition: GameDefinition
    let isUpdate: Bool
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    GameCard(definition: definition, favorite: false)
                    SlateCard {
                        SectionHeader(title: "Definition details", subtitle: "Review before adding this untrusted local file")
                        LabeledContent("Author", value: definition.source.author)
                        LabeledContent("Version", value: String(definition.definitionVersion))
                        LabeledContent("Fields", value: String(definition.inputs.count))
                        LabeledContent("Renderer", value: definition.layout.renderer.rawValue)
                    }
                    SlateCard {
                        SectionHeader(title: "Safety")
                        Label("Declarative scoring only", systemImage: "checkmark.shield.fill")
                        Label("No scripts, HTML, or network behavior", systemImage: "wifi.slash")
                        Label("Bounded fields and expressions", systemImage: "gauge.with.dots.needle.33percent")
                    }
                    PrimaryButton(title: isUpdate ? "Update Definition" : "Import Definition", icon: "square.and.arrow.down", action: onConfirm)
                        .accessibilityIdentifier("confirm-definition-import")
                }
                .padding()
            }
            .slateBackground()
            .navigationTitle(isUpdate ? "Review Update" : "Review Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

private struct GameDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingSetup = false
    @State private var activeSessionID: UUID?
    @State private var showingSession = false
    let definition: GameDefinition

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GameCard(definition: definition, favorite: isFavorite)
                SlateCard {
                    VStack(alignment: .leading, spacing: 14) {
                        detail("Players", "\(definition.players.minimum)–\(definition.players.maximum)", icon: "person.2.fill")
                        detail("Scoring", scoringStyle, icon: "number")
                        detail("Definition", "Version \(definition.definitionVersion) · \(definition.source.author)", icon: "doc.text.fill")
                        detail("Storage", "Works completely offline", icon: "iphone")
                    }
                }
                Button { store.toggleFavorite(definition.id) } label: {
                    Label(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "star.slash" : "star")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                if !definition.source.isBuiltIn {
                    Button(role: .destructive) {
                        store.deleteImportedDefinition(definition)
                        dismiss()
                    } label: {
                        Label("Delete Imported Definition", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                PrimaryButton(title: "Start Game", icon: "play.fill") { showingSetup = true }
            }
            .padding()
        }
        .slateBackground()
        .navigationTitle(definition.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSetup) {
            NavigationStack {
                GameSetupView(definition: definition) { id in
                    activeSessionID = id
                    showingSetup = false
                    showingSession = true
                }
                .navigationTitle(definition.name)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .fullScreenCover(isPresented: $showingSession) {
            if let activeSessionID {
                NavigationStack { ActiveSessionView(sessionID: activeSessionID) }
                    .environmentObject(store)
            }
        }
    }

    private var isFavorite: Bool { store.data.favoriteGameIDs.contains(definition.id) }

    private var scoringStyle: String {
        switch definition.session.type {
        case .roundBased: "Round-based"
        case .finalScore: "Final score sheet"
        case .continuousScore: "Continuous score"
        case .generic: "Flexible score sheet"
        }
    }

    private func detail(_ title: String, _ value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(SlateTheme.mint).frame(width: 26)
            VStack(alignment: .leading) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.body.weight(.semibold))
            }
        }
    }
}
