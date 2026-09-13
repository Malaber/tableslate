import Foundation

public enum ValidationState: Equatable, Sendable {
    case valid
    case warning(message: String, severity: ValidationSeverity)
}

public struct ScoringEngine: Sendable {
    private let evaluator: ExpressionEvaluator

    public init(evaluator: ExpressionEvaluator = .init()) {
        self.evaluator = evaluator
    }

    public func entryScore(_ entry: ScoreEntry, in session: GameSession) throws -> Int {
        let relatedEntries = session.scoreEntries.filter { $0.roundNumber == entry.roundNumber }
        let context = EvaluationContext(
            values: entry.values,
            roundEntries: relatedEntries,
            roundNumber: entry.roundNumber ?? session.currentRound,
            playerCount: session.players.count
        )
        return try evaluator.evaluate(session.definitionSnapshot.scoreRules.entryScore, context: context)
    }

    public func total(for playerID: UUID, in session: GameSession) -> Int {
        session.scoreEntries
            .filter { $0.playerID == playerID }
            .reduce(0) { sum, entry in
                let score = (try? entryScore(entry, in: session)) ?? 0
                let result = sum.addingReportingOverflow(score)
                return result.overflow ? (score >= 0 ? Int.max : Int.min) : result.partialValue
            }
    }

    public func results(for session: GameSession) -> [PlayerResult] {
        let scored = session.players.map { ($0, total(for: $0.id, in: session)) }
        let highestWins = session.configuration["highestWins"].map { $0 != 0 }
            ?? session.definitionSnapshot.resultRules.highestWins
        let ordered = scored.sorted {
            if $0.1 == $1.1 { return $0.0.name.localizedCaseInsensitiveCompare($1.0.name) == .orderedAscending }
            return highestWins ? $0.1 > $1.1 : $0.1 < $1.1
        }
        var previousScore: Int?
        var previousRank = 0
        return ordered.enumerated().map { index, item in
            let rank = item.1 == previousScore ? previousRank : index + 1
            previousScore = item.1
            previousRank = rank
            return PlayerResult(
                playerID: item.0.id,
                playerName: item.0.name,
                score: item.1,
                rank: rank,
                isWinner: rank == 1
            )
        }
    }

    public func maximumRounds(for session: GameSession) -> Int? {
        guard let expression = session.definitionSnapshot.progression?.maximumRounds else { return nil }
        let context = EvaluationContext(values: [:], roundNumber: session.currentRound, playerCount: session.players.count)
        return try? evaluator.evaluate(expression, context: context)
    }

    public func validation(forRound round: Int, in session: GameSession) -> [ValidationState] {
        let entries = session.scoreEntries.filter { $0.roundNumber == round }
        let context = EvaluationContext(
            values: [:],
            roundEntries: entries,
            roundNumber: round,
            playerCount: session.players.count
        )
        let warnings = session.definitionSnapshot.validationRules.compactMap { rule -> ValidationState? in
            guard let value = try? evaluator.evaluate(rule.expression, context: context), value == 0 else { return nil }
            return .warning(message: rule.message, severity: rule.severity)
        }
        return warnings.isEmpty ? [.valid] : warnings
    }

    public func entry(
        in session: GameSession,
        playerID: UUID,
        roundNumber: Int?
    ) -> ScoreEntry? {
        session.scoreEntries.first { $0.playerID == playerID && $0.roundNumber == roundNumber }
    }
}
