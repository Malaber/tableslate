import Foundation
import SwiftUI
import TableSlateCore

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published private(set) var builtInDefinitions: [GameDefinition]
    @Published var notice: AppNotice?

    private let persistence: AppDataStore?
    private let scoringEngine = ScoringEngine()
    private var undoSnapshots: [UUID: GameSession] = [:]

    init(bundle: Bundle = .main) {
        let resolvedPersistence = try? Self.applicationDataStore()
        persistence = resolvedPersistence
        let isUITestReset = ProcessInfo.processInfo.arguments.contains("--ui-testing-reset")
        if isUITestReset {
            if let fileURL = resolvedPersistence?.fileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
            ["appearance", "hapticsEnabled", "selectedTab"].forEach {
                UserDefaults.standard.removeObject(forKey: $0)
            }
        }
        let loadResult = isUITestReset
            ? PersistenceLoadResult(data: AppData())
            : (resolvedPersistence?.load() ?? PersistenceLoadResult(data: AppData()))
        data = loadResult.data
        builtInDefinitions = Self.loadBuiltIns(bundle: bundle)
        if let recoveryCopy = loadResult.recoveryCopy {
            notice = AppNotice(
                title: "Score history recovered",
                message: "Unreadable data was preserved as \(recoveryCopy.lastPathComponent). TableSlate started with a safe empty library."
            )
        }
    }

    var allDefinitions: [GameDefinition] {
        (builtInDefinitions + data.importedDefinitions)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var activeSessions: [GameSession] {
        data.activeSessions.sorted { $0.startedAt > $1.startedAt }
    }

    var completedSessions: [GameSession] {
        data.completedSessions.sorted { ($0.completedAt ?? $0.startedAt) > ($1.completedAt ?? $1.startedAt) }
    }

    func definition(id: String) -> GameDefinition? {
        allDefinitions.first { $0.id == id }
    }

    @discardableResult
    func addPlayer(name: String) -> Player? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }
        if let existing = data.players.first(where: { $0.name.localizedCaseInsensitiveCompare(cleanName) == .orderedSame }) {
            return existing
        }
        let player = Player(name: cleanName)
        data.players.append(player)
        data.players.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persist()
        return player
    }

    func deletePlayers(at offsets: IndexSet) {
        data.players.remove(atOffsets: offsets)
        persist()
    }

    func toggleFavorite(_ definitionID: String) {
        if data.favoriteGameIDs.contains(definitionID) {
            data.favoriteGameIDs.remove(definitionID)
        } else {
            data.favoriteGameIDs.insert(definitionID)
        }
        persist()
    }

    @discardableResult
    func startSession(
        definition: GameDefinition,
        playerIDs: [UUID],
        configuration: [String: Int] = [:]
    ) -> UUID? {
        var seen = Set<UUID>()
        let players = playerIDs.compactMap { id -> Player? in
            guard seen.insert(id).inserted else { return nil }
            return data.players.first { $0.id == id }
        }
        guard (definition.players.minimum...definition.players.maximum).contains(players.count) else {
            notice = AppNotice(
                title: "Choose players",
                message: "\(definition.name) supports \(definition.players.minimum)–\(definition.players.maximum) players."
            )
            return nil
        }
        var session = GameSession(definition: definition, players: players, configuration: configuration)
        if definition.session.type == .finalScore || (definition.session.type == .generic && configuration["scoringMode"] == 1) {
            session.scoreEntries = players.map { player in
                ScoreEntry(
                    playerID: player.id,
                    values: Dictionary(uniqueKeysWithValues: definition.inputs.map { ($0.id, 0) })
                )
            }
        }
        data.activeSessions.append(session)
        data.recentGameIDs.removeAll { $0 == definition.id }
        data.recentGameIDs.insert(definition.id, at: 0)
        data.recentGameIDs = Array(data.recentGameIDs.prefix(8))
        persist()
        return session.id
    }

    func session(id: UUID) -> GameSession? {
        data.activeSessions.first { $0.id == id }
    }

    func completedSession(id: UUID) -> GameSession? {
        data.completedSessions.first { $0.id == id }
    }

    func value(sessionID: UUID, playerID: UUID, field: String, round: Int?) -> Int {
        valueIfPresent(sessionID: sessionID, playerID: playerID, field: field, round: round) ?? 0
    }

    func valueIfPresent(sessionID: UUID, playerID: UUID, field: String, round: Int?) -> Int? {
        guard let session = session(id: sessionID) else { return nil }
        return scoringEngine.entry(in: session, playerID: playerID, roundNumber: round)?.values[field]
    }

    func setValue(sessionID: UUID, playerID: UUID, field: String, round: Int?, value: Int) {
        guard let index = data.activeSessions.firstIndex(where: { $0.id == sessionID }),
              let input = data.activeSessions[index].definitionSnapshot.inputs.first(where: { $0.id == field }) else { return }
        let lowerBound = input.minimum ?? (input.allowsNegative ? Int.min : 0)
        let upperBound = input.maximum ?? Int.max
        let boundedValue = min(upperBound, max(lowerBound, value))
        if let entryIndex = data.activeSessions[index].scoreEntries.firstIndex(where: {
            $0.playerID == playerID && $0.roundNumber == round
        }) {
            guard data.activeSessions[index].scoreEntries[entryIndex].values[field] != boundedValue else { return }
            rememberUndo(for: data.activeSessions[index])
            data.activeSessions[index].scoreEntries[entryIndex].values[field] = boundedValue
        } else {
            rememberUndo(for: data.activeSessions[index])
            data.activeSessions[index].scoreEntries.append(
                ScoreEntry(playerID: playerID, roundNumber: round, values: [field: boundedValue])
            )
        }
        persist()
    }

    func addValue(sessionID: UUID, playerID: UUID, field: String, round: Int?, delta: Int) {
        let current = value(sessionID: sessionID, playerID: playerID, field: field, round: round)
        let result = current.addingReportingOverflow(delta)
        let next = result.overflow ? (delta >= 0 ? Int.max : Int.min) : result.partialValue
        setValue(sessionID: sessionID, playerID: playerID, field: field, round: round, value: next)
    }

    func advanceRound(sessionID: UUID) {
        guard let index = data.activeSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        let session = data.activeSessions[index]
        rememberUndo(for: session)
        if scoringEngine.shouldEndGame(session)
            || scoringEngine.maximumRounds(for: session).map({ session.currentRound >= $0 }) == true {
            completeSession(id: sessionID)
            return
        }
        data.activeSessions[index].currentRound += 1
        persist()
    }

    func undo(sessionID: UUID) {
        guard let snapshot = undoSnapshots.removeValue(forKey: sessionID),
              let index = data.activeSessions.firstIndex(where: { $0.id == sessionID }) else { return }
        data.activeSessions[index] = snapshot
        persist()
    }

    func canUndo(sessionID: UUID) -> Bool {
        undoSnapshots[sessionID] != nil
    }

    func completeSession(id: UUID) {
        guard let index = data.activeSessions.firstIndex(where: { $0.id == id }) else { return }
        var session = data.activeSessions.remove(at: index)
        session.completedAt = Date()
        session.calculatedResults = scoringEngine.results(for: session)
        data.completedSessions.append(session)
        undoSnapshots.removeValue(forKey: id)
        persist()
    }

    func abandonSession(id: UUID) {
        data.activeSessions.removeAll { $0.id == id }
        undoSnapshots.removeValue(forKey: id)
        persist()
    }

    func prepareDefinitionImport(from url: URL) -> GameDefinition? {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            guard url.lastPathComponent.lowercased().hasSuffix(".tableslate-game.json") else {
                throw ImportError.wrongFileExtension
            }
            let raw = try Data(contentsOf: url, options: [.mappedIfSafe])
            guard raw.count <= 512_000 else {
                throw ImportError.fileTooLarge
            }
            let definition = try DefinitionValidator().decodeAndValidate(raw)
            guard !builtInDefinitions.contains(where: { $0.id == definition.id }) else {
                throw ImportError.cannotReplaceBuiltIn
            }
            if let index = data.importedDefinitions.firstIndex(where: { $0.id == definition.id }) {
                guard definition.definitionVersion > data.importedDefinitions[index].definitionVersion else {
                    throw ImportError.versionMustIncrease
                }
            }
            return definition
        } catch {
            notice = AppNotice(title: "This game definition cannot be imported", message: error.localizedDescription)
            return nil
        }
    }

    func installImportedDefinition(_ definition: GameDefinition) {
        do {
            try DefinitionValidator().validate(definition)
            guard !builtInDefinitions.contains(where: { $0.id == definition.id }) else {
                throw ImportError.cannotReplaceBuiltIn
            }
            if let index = data.importedDefinitions.firstIndex(where: { $0.id == definition.id }) {
                guard definition.definitionVersion > data.importedDefinitions[index].definitionVersion else {
                    throw ImportError.versionMustIncrease
                }
                data.importedDefinitions[index] = definition
            } else {
                data.importedDefinitions.append(definition)
            }
            persist()
            notice = AppNotice(title: "Game imported", message: "\(definition.name) is now available in Games.")
        } catch {
            notice = AppNotice(title: "This game definition cannot be imported", message: error.localizedDescription)
        }
    }

    func isDefinitionUpdate(_ definition: GameDefinition) -> Bool {
        data.importedDefinitions.contains { $0.id == definition.id }
    }

    func deleteImportedDefinition(_ definition: GameDefinition) {
        guard !definition.source.isBuiltIn else { return }
        data.importedDefinitions.removeAll { $0.id == definition.id }
        data.favoriteGameIDs.remove(definition.id)
        persist()
    }

    func results(for session: GameSession) -> [PlayerResult] {
        scoringEngine.results(for: session)
    }

    func entryScore(_ entry: ScoreEntry, session: GameSession) -> Int {
        (try? scoringEngine.entryScore(entry, in: session)) ?? 0
    }

    func validation(forRound round: Int, session: GameSession) -> [ValidationState] {
        scoringEngine.validation(forRound: round, in: session)
    }

    func maximumRounds(for session: GameSession) -> Int? {
        scoringEngine.maximumRounds(for: session)
    }

    func shouldEndGame(_ session: GameSession) -> Bool {
        scoringEngine.shouldEndGame(session)
    }

    private func rememberUndo(for session: GameSession) {
        undoSnapshots[session.id] = session
    }

    private func persist() {
        do {
            try persistence?.save(data)
        } catch {
            notice = AppNotice(title: "Couldn’t save", message: "Your latest change is still open, but could not be written to storage.")
        }
    }

    private static func loadBuiltIns(bundle: Bundle) -> [GameDefinition] {
        let validator = DefinitionValidator()
        let nested = bundle.urls(forResourcesWithExtension: "json", subdirectory: "Builtin") ?? []
        let flat = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let urls = Dictionary(uniqueKeysWithValues: (nested + flat).map { ($0.lastPathComponent, $0) }).values
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  var definition = try? validator.decodeAndValidate(data, imported: false) else { return nil }
            definition.source.isBuiltIn = true
            return definition
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func applicationDataStore() throws -> AppDataStore {
        let manager = FileManager.default
        let root = try manager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return try AppDataStore.applicationSupport(baseDirectory: root, fileManager: manager)
    }
}

struct AppNotice: Identifiable {
    let id = UUID()
    var title: String
    var message: String
}

enum ImportError: Error, LocalizedError {
    case wrongFileExtension
    case fileTooLarge
    case cannotReplaceBuiltIn
    case versionMustIncrease

    var errorDescription: String? {
        switch self {
        case .wrongFileExtension: "Choose a file ending in .tableslate-game.json."
        case .fileTooLarge: "The definition is larger than 500 KB."
        case .cannotReplaceBuiltIn: "Built-in games cannot be replaced."
        case .versionMustIncrease: "An update must have a higher definition version."
        }
    }
}
