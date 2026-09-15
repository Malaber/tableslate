import Foundation

public struct Player: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }
}

public struct PlayerConstraints: Codable, Equatable, Sendable {
    public var minimum: Int
    public var maximum: Int

    public init(minimum: Int, maximum: Int) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public enum SessionType: String, Codable, Sendable {
    case roundBased
    case finalScore
    case continuousScore
    case generic
}

public struct SessionDefinition: Codable, Equatable, Sendable {
    public var type: SessionType

    public init(type: SessionType) { self.type = type }
}

public enum RendererFamily: String, Codable, Sendable {
    case roundTable
    case scoreForm
    case scoreCounter
}

public struct LayoutDefinition: Codable, Equatable, Sendable {
    public var renderer: RendererFamily

    public init(renderer: RendererFamily) { self.renderer = renderer }
}

public struct InputDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var label: String
    public var group: String?
    public var minimum: Int?
    public var maximum: Int?
    public var allowsNegative: Bool
    public var quickValues: [Int]

    public init(
        id: String,
        label: String,
        group: String? = nil,
        minimum: Int? = nil,
        maximum: Int? = nil,
        allowsNegative: Bool = false,
        quickValues: [Int] = []
    ) {
        self.id = id
        self.label = label
        self.group = group
        self.minimum = minimum
        self.maximum = maximum
        self.allowsNegative = allowsNegative
        self.quickValues = quickValues
    }
}

public enum ExpressionOperation: String, Codable, Sendable {
    case add, subtract, multiply, divide, abs, min, max
    case equals, greaterThan, lessThan, `if`, sum, count
    case field, constant, roundNumber, playerCount
}

public struct Expression: Codable, Equatable, Sendable {
    public var operation: ExpressionOperation
    public var value: Int?
    public var field: String?
    public var arguments: [Expression]

    public init(
        _ operation: ExpressionOperation,
        value: Int? = nil,
        field: String? = nil,
        arguments: [Expression] = []
    ) {
        self.operation = operation
        self.value = value
        self.field = field
        self.arguments = arguments
    }
}

public struct ScoreRules: Codable, Equatable, Sendable {
    public var entryScore: Expression

    public init(entryScore: Expression) { self.entryScore = entryScore }
}

public enum ValidationSeverity: String, Codable, Sendable {
    case invalid, suspicious
}

public struct ValidationRule: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var message: String
    public var severity: ValidationSeverity
    public var expression: Expression

    public init(id: String, message: String, severity: ValidationSeverity, expression: Expression) {
        self.id = id
        self.message = message
        self.severity = severity
        self.expression = expression
    }
}

public struct ProgressionDefinition: Codable, Equatable, Sendable {
    public var maximumRounds: Expression?
    public var endWhenAnyScoreReaches: Expression?

    public init(
        maximumRounds: Expression? = nil,
        endWhenAnyScoreReaches: Expression? = nil
    ) {
        self.maximumRounds = maximumRounds
        self.endWhenAnyScoreReaches = endWhenAnyScoreReaches
    }
}

public struct ResultRules: Codable, Equatable, Sendable {
    public var highestWins: Bool

    public init(highestWins: Bool = true) { self.highestWins = highestWins }
}

public struct DefinitionSource: Codable, Equatable, Sendable {
    public var author: String
    public var isBuiltIn: Bool

    public init(author: String = "TableSlate", isBuiltIn: Bool = true) {
        self.author = author
        self.isBuiltIn = isBuiltIn
    }
}

public struct GameDefinition: Codable, Equatable, Identifiable, Sendable {
    public var schemaVersion: Int
    public var id: String
    public var definitionVersion: Int
    public var name: String
    public var aliases: [String]
    public var players: PlayerConstraints
    public var session: SessionDefinition
    public var layout: LayoutDefinition
    public var inputs: [InputDefinition]
    public var progression: ProgressionDefinition?
    public var scoreRules: ScoreRules
    public var validationRules: [ValidationRule]
    public var resultRules: ResultRules
    public var source: DefinitionSource

    public init(
        schemaVersion: Int = 1,
        id: String,
        definitionVersion: Int = 1,
        name: String,
        aliases: [String] = [],
        players: PlayerConstraints,
        session: SessionDefinition,
        layout: LayoutDefinition,
        inputs: [InputDefinition],
        progression: ProgressionDefinition? = nil,
        scoreRules: ScoreRules,
        validationRules: [ValidationRule] = [],
        resultRules: ResultRules = .init(),
        source: DefinitionSource = .init()
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.definitionVersion = definitionVersion
        self.name = name
        self.aliases = aliases
        self.players = players
        self.session = session
        self.layout = layout
        self.inputs = inputs
        self.progression = progression
        self.scoreRules = scoreRules
        self.validationRules = validationRules
        self.resultRules = resultRules
        self.source = source
    }
}

public struct SessionPlayer: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String

    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    public init(_ player: Player) {
        self.init(id: player.id, name: player.name)
    }
}

public struct ScoreEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var playerID: UUID
    public var roundNumber: Int?
    public var values: [String: Int]

    public init(
        id: UUID = UUID(),
        playerID: UUID,
        roundNumber: Int? = nil,
        values: [String: Int] = [:]
    ) {
        self.id = id
        self.playerID = playerID
        self.roundNumber = roundNumber
        self.values = values
    }
}

public struct PlayerResult: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID { playerID }
    public var playerID: UUID
    public var playerName: String
    public var score: Int
    public var rank: Int
    public var isWinner: Bool

    public init(playerID: UUID, playerName: String, score: Int, rank: Int, isWinner: Bool) {
        self.playerID = playerID
        self.playerName = playerName
        self.score = score
        self.rank = rank
        self.isWinner = isWinner
    }
}

public struct GameSession: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var definitionID: String
    public var definitionVersion: Int
    public var definitionSnapshot: GameDefinition
    public var players: [SessionPlayer]
    public var startedAt: Date
    public var completedAt: Date?
    public var currentRound: Int
    public var configuration: [String: Int]
    public var scoreEntries: [ScoreEntry]
    public var calculatedResults: [PlayerResult]

    public init(
        id: UUID = UUID(),
        definition: GameDefinition,
        players: [Player],
        startedAt: Date = Date(),
        configuration: [String: Int] = [:]
    ) {
        self.id = id
        self.definitionID = definition.id
        self.definitionVersion = definition.definitionVersion
        self.definitionSnapshot = definition
        self.players = players.map(SessionPlayer.init)
        self.startedAt = startedAt
        self.completedAt = nil
        self.currentRound = 1
        self.configuration = configuration
        self.scoreEntries = []
        self.calculatedResults = []
    }
}

public struct AppData: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var players: [Player]
    public var favoriteGameIDs: Set<String>
    public var recentGameIDs: [String]
    public var activeSessions: [GameSession]
    public var completedSessions: [GameSession]
    public var importedDefinitions: [GameDefinition]

    public init(
        schemaVersion: Int = currentSchemaVersion,
        players: [Player] = [],
        favoriteGameIDs: Set<String> = [],
        recentGameIDs: [String] = [],
        activeSessions: [GameSession] = [],
        completedSessions: [GameSession] = [],
        importedDefinitions: [GameDefinition] = []
    ) {
        self.schemaVersion = schemaVersion
        self.players = players
        self.favoriteGameIDs = favoriteGameIDs
        self.recentGameIDs = recentGameIDs
        self.activeSessions = activeSessions
        self.completedSessions = completedSessions
        self.importedDefinitions = importedDefinitions
    }
}
