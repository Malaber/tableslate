import Foundation
import XCTest
@testable import TableSlateCore

final class TableSlateCoreTests: XCTestCase {
    private let validator = DefinitionValidator()

    func testBuiltInDefinitionsDecodeAndValidate() throws {
        let names = ["wizard", "cascadia", "generic-score", "skyjo", "romme"]
        for name in names {
            let definition = try loadDefinition(name)
            try validator.validate(definition)
            XCTAssertEqual(definition.schemaVersion, 1)
            XCTAssertFalse(definition.inputs.isEmpty)
        }
    }

    func testWizardScoringAndRoundCount() throws {
        let wizard = try loadDefinition("wizard")
        let players = [Player(name: "Daniel"), Player(name: "Luisa"), Player(name: "Pascal")]
        var session = GameSession(definition: wizard, players: players)
        session.scoreEntries = [
            ScoreEntry(playerID: players[0].id, roundNumber: 1, values: ["bid": 1, "tricks": 1]),
            ScoreEntry(playerID: players[1].id, roundNumber: 1, values: ["bid": 1, "tricks": 0]),
            ScoreEntry(playerID: players[2].id, roundNumber: 1, values: ["bid": 0, "tricks": 0]),
        ]
        let engine = ScoringEngine()

        XCTAssertEqual(try engine.entryScore(session.scoreEntries[0], in: session), 30)
        XCTAssertEqual(try engine.entryScore(session.scoreEntries[1], in: session), -10)
        XCTAssertEqual(try engine.entryScore(session.scoreEntries[2], in: session), 20)
        XCTAssertEqual(engine.maximumRounds(for: session), 20)
        XCTAssertEqual(engine.validation(forRound: 1, in: session), [.valid])
    }

    func testWizardValidationWarnsWithoutBlocking() throws {
        let wizard = try loadDefinition("wizard")
        let players = [Player(name: "A"), Player(name: "B"), Player(name: "C")]
        var session = GameSession(definition: wizard, players: players)
        session.currentRound = 2
        session.scoreEntries = players.map {
            ScoreEntry(playerID: $0.id, roundNumber: 2, values: ["bid": 0, "tricks": 0])
        }

        let states = ScoringEngine().validation(forRound: 2, in: session)
        XCTAssertEqual(states, [.warning(message: "The total tricks must match this round.", severity: .invalid)])
    }

    func testCascadiaTotalsAllCategories() throws {
        let definition = try loadDefinition("cascadia")
        let player = Player(name: "Mara")
        var session = GameSession(definition: definition, players: [player])
        session.scoreEntries = [ScoreEntry(
            playerID: player.id,
            values: Dictionary(uniqueKeysWithValues: definition.inputs.map { ($0.id, 5) })
        )]

        XCTAssertEqual(ScoringEngine().total(for: player.id, in: session), 55)
    }

    func testGenericRankingSupportsHighestLowestAndTies() throws {
        let definition = try loadDefinition("generic-score")
        let players = [Player(name: "A"), Player(name: "B"), Player(name: "C")]
        var session = GameSession(definition: definition, players: players)
        session.scoreEntries = [
            ScoreEntry(playerID: players[0].id, values: ["score": 4]),
            ScoreEntry(playerID: players[1].id, values: ["score": 9]),
            ScoreEntry(playerID: players[2].id, values: ["score": 9]),
        ]
        var results = ScoringEngine().results(for: session)
        XCTAssertEqual(results.map(\.score), [9, 9, 4])
        XCTAssertEqual(results.map(\.rank), [1, 1, 3])
        XCTAssertEqual(results.filter(\.isWinner).count, 2)

        session.configuration["highestWins"] = 0
        results = ScoringEngine().results(for: session)
        XCTAssertEqual(results.first?.score, 4)
    }

    func testSkyjoTotalsLowestWinsAndEndsAtOneHundred() throws {
        let definition = try loadDefinition("skyjo")
        let players = [Player(name: "A"), Player(name: "B")]
        var session = GameSession(definition: definition, players: players)
        session.scoreEntries = [
            ScoreEntry(playerID: players[0].id, roundNumber: 1, values: ["round-points": 72]),
            ScoreEntry(playerID: players[1].id, roundNumber: 1, values: ["round-points": 20]),
        ]
        let engine = ScoringEngine()

        XCTAssertEqual(engine.endScoreThreshold(for: session), 100)
        XCTAssertFalse(engine.shouldEndGame(session))

        session.scoreEntries += [
            ScoreEntry(playerID: players[0].id, roundNumber: 2, values: ["round-points": 31]),
            ScoreEntry(playerID: players[1].id, roundNumber: 2, values: ["round-points": -2]),
        ]
        XCTAssertTrue(engine.shouldEndGame(session))
        XCTAssertEqual(engine.results(for: session).map(\.score), [18, 103])
        XCTAssertEqual(engine.results(for: session).first?.playerName, "B")
    }

    func testRommeAddsPenaltyPointsAndLowestWins() throws {
        let definition = try loadDefinition("romme")
        let players = [Player(name: "A"), Player(name: "B")]
        var session = GameSession(definition: definition, players: players)
        session.scoreEntries = [
            ScoreEntry(playerID: players[0].id, roundNumber: 1, values: ["penalty-points": 0]),
            ScoreEntry(playerID: players[1].id, roundNumber: 1, values: ["penalty-points": 47]),
            ScoreEntry(playerID: players[0].id, roundNumber: 2, values: ["penalty-points": 32]),
            ScoreEntry(playerID: players[1].id, roundNumber: 2, values: ["penalty-points": 0]),
        ]

        let results = ScoringEngine().results(for: session)
        XCTAssertEqual(results.map(\.score), [32, 47])
        XCTAssertEqual(results.first?.playerName, "A")
    }

    func testExpressionOperationsAndFailures() throws {
        let evaluator = ExpressionEvaluator()
        let context = EvaluationContext(values: ["x": -4], playerCount: 3)
        let expression = Expression(.max, arguments: [
            Expression(.abs, arguments: [Expression(.field, field: "x")]),
            Expression(.divide, arguments: [Expression(.constant, value: 9), Expression(.constant, value: 3)]),
        ])
        XCTAssertEqual(try evaluator.evaluate(expression, context: context), 4)
        XCTAssertThrowsError(try evaluator.evaluate(Expression(.field, field: "missing"), context: context))
        XCTAssertThrowsError(try evaluator.evaluate(
            Expression(.divide, arguments: [Expression(.constant, value: 1), Expression(.constant, value: 0)]),
            context: context
        ))
    }

    func testEveryExpressionPrimitive() throws {
        let entries = [
            ScoreEntry(playerID: UUID(), values: ["points": 2]),
            ScoreEntry(playerID: UUID(), values: ["points": 3]),
            ScoreEntry(playerID: UUID(), values: [:]),
        ]
        let context = EvaluationContext(values: ["x": 4], roundEntries: entries, roundNumber: 7, playerCount: 2)
        let evaluator = ExpressionEvaluator()
        let constant = { Expression(.constant, value: $0) }

        XCTAssertEqual(try evaluator.evaluate(Expression(.add, arguments: [constant(2), constant(3)]), context: context), 5)
        XCTAssertEqual(try evaluator.evaluate(Expression(.subtract, arguments: [constant(9), constant(2), constant(1)]), context: context), 6)
        XCTAssertEqual(try evaluator.evaluate(Expression(.multiply, arguments: [constant(3), constant(4)]), context: context), 12)
        XCTAssertEqual(try evaluator.evaluate(Expression(.min, arguments: [constant(3), constant(4)]), context: context), 3)
        XCTAssertEqual(try evaluator.evaluate(Expression(.equals, arguments: [constant(3), constant(3)]), context: context), 1)
        XCTAssertEqual(try evaluator.evaluate(Expression(.greaterThan, arguments: [constant(4), constant(3)]), context: context), 1)
        XCTAssertEqual(try evaluator.evaluate(Expression(.greaterThan, arguments: [constant(3), constant(4)]), context: context), 0)
        XCTAssertEqual(try evaluator.evaluate(Expression(.lessThan, arguments: [constant(4), constant(3)]), context: context), 0)
        XCTAssertEqual(try evaluator.evaluate(Expression(.if, arguments: [constant(1), constant(8), constant(9)]), context: context), 8)
        XCTAssertEqual(try evaluator.evaluate(Expression(.sum, arguments: [constant(2), constant(4)]), context: context), 6)
        XCTAssertEqual(try evaluator.evaluate(Expression(.sum, field: "points"), context: context), 5)
        XCTAssertEqual(try evaluator.evaluate(Expression(.count, arguments: [constant(2), constant(4)]), context: context), 2)
        XCTAssertEqual(try evaluator.evaluate(Expression(.count, field: "points"), context: context), 2)
        XCTAssertEqual(try evaluator.evaluate(Expression(.roundNumber), context: context), 7)
        XCTAssertEqual(try evaluator.evaluate(Expression(.playerCount), context: context), 2)
    }

    func testExpressionsRejectInvalidArityComplexityAndOverflow() throws {
        let context = EvaluationContext(values: [:], playerCount: 1)
        let evaluator = ExpressionEvaluator(maximumDepth: 0)
        XCTAssertThrowsError(try evaluator.evaluate(Expression(.constant), context: context))
        XCTAssertThrowsError(try evaluator.evaluate(Expression(.subtract, arguments: [Expression(.constant, value: 1)]), context: context))
        XCTAssertThrowsError(try evaluator.evaluate(Expression(.min), context: context))
        XCTAssertThrowsError(try evaluator.evaluate(Expression(.max), context: context))
        XCTAssertThrowsError(try evaluator.evaluate(Expression(.abs, arguments: [Expression(.constant, value: 1), Expression(.constant, value: 2)]), context: context))
        XCTAssertThrowsError(try evaluator.evaluate(Expression(.equals, arguments: [Expression(.constant, value: 1)]), context: context))
        XCTAssertThrowsError(try evaluator.evaluate(Expression(.if, arguments: [Expression(.constant, value: 1)]), context: context))
        XCTAssertThrowsError(try evaluator.evaluate(Expression(.add, arguments: [Expression(.constant, value: 1)]), context: context))

        let normal = ExpressionEvaluator()
        XCTAssertThrowsError(try normal.evaluate(Expression(.add, arguments: [Expression(.constant, value: Int.max), Expression(.constant, value: 1)]), context: context))
        XCTAssertThrowsError(try normal.evaluate(Expression(.multiply, arguments: [Expression(.constant, value: Int.max), Expression(.constant, value: 2)]), context: context))
        XCTAssertThrowsError(try normal.evaluate(Expression(.abs, arguments: [Expression(.constant, value: Int.min)]), context: context))
        XCTAssertThrowsError(try normal.evaluate(Expression(.field), context: context))
        XCTAssertThrowsError(try normal.evaluate(
            Expression(.subtract, arguments: [Expression(.constant, value: Int.min), Expression(.constant, value: 1)]),
            context: context
        ))
    }

    func testDefinitionValidationRejectsUnsafeShapes() throws {
        var definition = try loadDefinition("generic-score")
        definition.schemaVersion = 2
        XCTAssertThrowsError(try validator.validate(definition))

        definition.schemaVersion = 1
        definition.id = "Not valid"
        XCTAssertThrowsError(try validator.validate(definition))

        definition.id = "valid"
        definition.inputs.append(definition.inputs[0])
        XCTAssertThrowsError(try validator.validate(definition))

        definition.inputs.removeLast()
        definition.players = PlayerConstraints(minimum: 4, maximum: 2)
        XCTAssertThrowsError(try validator.validate(definition))

        definition.players = PlayerConstraints(minimum: 1, maximum: 2)
        XCTAssertThrowsError(try DefinitionValidator(maximumInputs: 0).validate(definition))
        XCTAssertThrowsError(try DefinitionValidator(maximumExpressionNodes: 0).validate(definition))
    }

    func testDecodeAndValidateMarksCommunitySource() throws {
        let definition = try loadDefinition("generic-score")
        let encoded = try JSONEncoder().encode(definition)
        let imported = try validator.decodeAndValidate(encoded)
        XCTAssertFalse(imported.source.isBuiltIn)
        XCTAssertTrue(try validator.decodeAndValidate(encoded, imported: false).source.isBuiltIn)
    }

    func testDefinitionValidationRejectsBadFieldsRangesAndExpressionShapes() throws {
        var definition = try loadDefinition("generic-score")
        definition.inputs[0].minimum = 10
        definition.inputs[0].maximum = 2
        XCTAssertThrowsError(try validator.validate(definition))

        definition = try loadDefinition("generic-score")
        definition.scoreRules.entryScore = Expression(.field, field: "unknown")
        XCTAssertThrowsError(try validator.validate(definition)) { error in
            XCTAssertEqual(error as? DefinitionValidationError, .invalidExpressionField("unknown"))
        }

        definition.scoreRules.entryScore = Expression(.divide, arguments: [Expression(.constant, value: 1)])
        XCTAssertThrowsError(try validator.validate(definition))

        definition = try loadDefinition("generic-score")
        definition.validationRules = [
            ValidationRule(id: "same", message: "One", severity: .invalid, expression: Expression(.constant, value: 1)),
            ValidationRule(id: "same", message: "Two", severity: .invalid, expression: Expression(.constant, value: 1)),
        ]
        XCTAssertThrowsError(try validator.validate(definition))

        definition = try loadDefinition("generic-score")
        definition.inputs = []
        XCTAssertThrowsError(try validator.validate(definition))

        definition = try loadDefinition("generic-score")
        definition.validationRules = [
            ValidationRule(id: "blank", message: "  ", severity: .invalid, expression: Expression(.constant, value: 1)),
        ]
        XCTAssertThrowsError(try validator.validate(definition))

        definition = try loadDefinition("generic-score")
        definition.scoreRules.entryScore = Expression(.min, arguments: [
            Expression(.field, field: "score"),
            Expression(.constant, value: 100),
        ])
        XCTAssertNoThrow(try validator.validate(definition))
    }

    func testDefinitionValidationAcceptsBoundedQuickValuesAndAggregateArguments() throws {
        var definition = try loadDefinition("generic-score")
        definition.inputs[0].minimum = -2
        definition.inputs[0].maximum = 2
        definition.inputs[0].allowsNegative = true
        definition.inputs[0].quickValues = [-2, 0, 2]
        definition.scoreRules.entryScore = Expression(.sum, arguments: [
            Expression(.field, field: "score"),
            Expression(.constant, value: 1),
        ])
        XCTAssertNoThrow(try validator.validate(definition))

        definition.scoreRules.entryScore = Expression(.count, arguments: [
            Expression(.field, field: "score"),
        ])
        XCTAssertNoThrow(try validator.validate(definition))
    }

    func testValidationAndExpressionErrorsHaveImportSafeMessages() {
        let definitionErrors: [DefinitionValidationError] = [
            .unsupportedSchema(9),
            .invalidIdentifier,
            .invalidDefinition,
            .invalidPlayerRange,
            .invalidInput("points"),
            .tooManyInputs,
            .duplicateInput("points"),
            .duplicateValidationRule("total"),
            .invalidExpressionField("missing"),
            .invalidExpressionShape(.divide),
            .expressionTooComplex,
        ]
        XCTAssertTrue(definitionErrors.allSatisfy { !($0.errorDescription ?? "").isEmpty })

        let expressionErrors: [ExpressionError] = [
            .missingValue("points"),
            .invalidArity(.add),
            .divisionByZero,
            .numericOverflow,
            .complexityLimit,
        ]
        XCTAssertTrue(expressionErrors.allSatisfy { !($0.errorDescription ?? "").isEmpty })
    }

    func testPublicModelInitializers() {
        let constraints = PlayerConstraints(minimum: 2, maximum: 4)
        let session = SessionDefinition(type: .continuousScore)
        let layout = LayoutDefinition(renderer: .scoreCounter)
        let input = InputDefinition(id: "points", label: "Points", group: "Round", minimum: -5, maximum: 20, allowsNegative: true, quickValues: [-1, 1])
        let scoreRules = ScoreRules(entryScore: Expression(.field, field: "points"))
        let validation = ValidationRule(id: "positive", message: "Check score", severity: .suspicious, expression: Expression(.greaterThan, arguments: []))
        let progression = ProgressionDefinition(
            maximumRounds: Expression(.constant, value: 10),
            endWhenAnyScoreReaches: Expression(.constant, value: 100)
        )
        let results = ResultRules(highestWins: false)
        let source = DefinitionSource(author: "Community", isBuiltIn: false)
        let definition = GameDefinition(
            id: "example", name: "Example", aliases: ["Demo"], players: constraints,
            session: session, layout: layout, inputs: [input], progression: progression,
            scoreRules: scoreRules, validationRules: [validation], resultRules: results, source: source
        )
        let player = Player(id: UUID(), name: " Alex ", createdAt: Date(timeIntervalSince1970: 2))
        let sessionPlayer = SessionPlayer(player)
        let entry = ScoreEntry(playerID: player.id, roundNumber: 2, values: ["points": 4])
        let result = PlayerResult(playerID: player.id, playerName: player.name, score: 4, rank: 1, isWinner: true)
        let appData = AppData(recentGameIDs: [definition.id], activeSessions: [], completedSessions: [], importedDefinitions: [definition])

        XCTAssertEqual(player.name, "Alex")
        XCTAssertEqual(sessionPlayer.name, "Alex")
        XCTAssertEqual(entry.values["points"], 4)
        XCTAssertTrue(result.isWinner)
        XCTAssertEqual(result.id, player.id)
        XCTAssertEqual(appData.importedDefinitions.first?.source.author, "Community")
    }

    func testSessionKeepsDefinitionSnapshot() throws {
        var definition = try loadDefinition("generic-score")
        let session = GameSession(definition: definition, players: [Player(name: "A")])
        definition.definitionVersion = 2
        definition.name = "Changed"
        XCTAssertEqual(session.definitionVersion, 1)
        XCTAssertEqual(session.definitionSnapshot.name, "Generic Score")
    }

    func testPersistenceRoundTripAndCorruptRecovery() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("app-data.json")
        let store = AppDataStore(fileURL: url)
        let player = Player(name: "Daniel", createdAt: Date(timeIntervalSince1970: 1_000))
        let expected = AppData(players: [player], favoriteGameIDs: ["wizard"])
        try store.save(expected)
        XCTAssertEqual(store.load().data, expected)

        try Data("not json".utf8).write(to: url)
        let recovered = store.load()
        XCTAssertEqual(recovered.data, AppData())
        XCTAssertNotNil(recovered.recoveryCopy)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recovered.recoveryCopy!.path))

        let supportRoot = directory.appendingPathComponent("support", isDirectory: true)
        let supportStore = try AppDataStore.applicationSupport(baseDirectory: supportRoot)
        XCTAssertEqual(supportStore.fileURL, supportRoot.appendingPathComponent("TableSlate/app-data.json"))
    }

    func testPersistenceFallsBackWhenRecoveryCopyCannotBeCreated() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("app-data.json")
        try Data("not json".utf8).write(to: url)
        let instant = Date(timeIntervalSince1970: 1_000)
        let stamp = ISO8601DateFormatter().string(from: instant).replacingOccurrences(of: ":", with: "-")
        let occupiedRecoveryURL = url.deletingPathExtension().appendingPathExtension("corrupt-\(stamp).json")
        try Data("occupied".utf8).write(to: occupiedRecoveryURL)

        let load = AppDataStore(fileURL: url, now: { instant }).load()
        XCTAssertEqual(load.data, AppData())
        XCTAssertNil(load.recoveryCopy)
    }

    func testScoringLookupAndMissingProgression() throws {
        let definition = try loadDefinition("generic-score")
        let player = Player(name: "A")
        var session = GameSession(definition: definition, players: [player])
        let entry = ScoreEntry(playerID: player.id, roundNumber: 1, values: ["score": 3])
        session.scoreEntries = [entry]
        let engine = ScoringEngine()

        XCTAssertEqual(engine.entry(in: session, playerID: player.id, roundNumber: 1), entry)
        XCTAssertNil(engine.entry(in: session, playerID: UUID(), roundNumber: 1))
        XCTAssertNil(engine.maximumRounds(for: session))
        XCTAssertNil(engine.endScoreThreshold(for: session))
        XCTAssertFalse(engine.shouldEndGame(session))

        session.definitionSnapshot.progression = ProgressionDefinition(
            endWhenAnyScoreReaches: Expression(.constant, value: 0)
        )
        XCTAssertNil(engine.endScoreThreshold(for: session))
    }

    func testScoringTotalTreatsInvalidEntriesAsZeroAndSaturatesOverflow() throws {
        let definition = try loadDefinition("generic-score")
        let player = Player(name: "A")
        let engine = ScoringEngine()

        var invalid = GameSession(definition: definition, players: [player])
        invalid.scoreEntries = [ScoreEntry(playerID: player.id, values: [:])]
        XCTAssertEqual(engine.total(for: player.id, in: invalid), 0)

        var positive = GameSession(definition: definition, players: [player])
        positive.scoreEntries = [
            ScoreEntry(playerID: player.id, values: ["score": Int.max]),
            ScoreEntry(playerID: player.id, values: ["score": 1]),
        ]
        XCTAssertEqual(engine.total(for: player.id, in: positive), Int.max)

        var negative = GameSession(definition: definition, players: [player])
        negative.scoreEntries = [
            ScoreEntry(playerID: player.id, values: ["score": Int.min]),
            ScoreEntry(playerID: player.id, values: ["score": -1]),
        ]
        XCTAssertEqual(engine.total(for: player.id, in: negative), Int.min)
    }

    func testPersistenceStartsEmptyAndPreservesFutureSchemaAsRecovery() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("app-data.json")
        let store = AppDataStore(fileURL: url)
        XCTAssertEqual(store.load().data, AppData())

        try store.save(AppData(schemaVersion: 99, players: [Player(name: "Future")]))
        let load = store.load()
        XCTAssertEqual(load.data, AppData())
        XCTAssertNotNil(load.recoveryCopy)
    }

    func testStatisticsAreDerivedFromHistory() throws {
        let definition = try loadDefinition("generic-score")
        let player = Player(name: "Daniel")
        var first = GameSession(definition: definition, players: [player])
        first.calculatedResults = [PlayerResult(playerID: player.id, playerName: player.name, score: 10, rank: 1, isWinner: true)]
        var second = GameSession(definition: definition, players: [player])
        second.calculatedResults = [PlayerResult(playerID: player.id, playerName: player.name, score: 20, rank: 2, isWinner: false)]

        let statistics = Statistics.player(player.id, sessions: [first, second])
        XCTAssertEqual(statistics.gamesPlayed, 2)
        XCTAssertEqual(statistics.wins, 1)
        XCTAssertEqual(statistics.averageScore, 15)
        XCTAssertEqual(statistics.highestScore, 20)
    }

    func testStatisticsAverageDoesNotOverflow() throws {
        let definition = try loadDefinition("generic-score")
        let player = Player(name: "Daniel")
        var first = GameSession(definition: definition, players: [player])
        first.calculatedResults = [PlayerResult(playerID: player.id, playerName: player.name, score: Int.max, rank: 1, isWinner: true)]
        var second = GameSession(definition: definition, players: [player])
        second.calculatedResults = [PlayerResult(playerID: player.id, playerName: player.name, score: Int.max, rank: 1, isWinner: true)]

        let statistics = Statistics.player(player.id, sessions: [first, second])
        XCTAssertTrue(statistics.averageScore.isFinite)
        XCTAssertEqual(statistics.highestScore, Int.max)
    }

    private func loadDefinition(_ name: String) throws -> GameDefinition {
        let packageRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = packageRoot
            .appendingPathComponent("Definitions/Builtin")
            .appendingPathComponent("\(name).json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(GameDefinition.self, from: data)
    }
}
