import Foundation

public struct PlayerStatistics: Equatable, Sendable {
    public var gamesPlayed: Int
    public var wins: Int
    public var averageScore: Double
    public var highestScore: Int?

    public init(gamesPlayed: Int, wins: Int, averageScore: Double, highestScore: Int?) {
        self.gamesPlayed = gamesPlayed
        self.wins = wins
        self.averageScore = averageScore
        self.highestScore = highestScore
    }
}

public enum Statistics {
    public static func player(_ playerID: UUID, sessions: [GameSession]) -> PlayerStatistics {
        let results = sessions.compactMap { session in
            session.calculatedResults.first { $0.playerID == playerID }
        }
        return PlayerStatistics(
            gamesPlayed: results.count,
            wins: results.filter(\.isWinner).count,
            averageScore: results.isEmpty ? 0 : results.reduce(0.0) { $0 + Double($1.score) } / Double(results.count),
            highestScore: results.map(\.score).max()
        )
    }
}
