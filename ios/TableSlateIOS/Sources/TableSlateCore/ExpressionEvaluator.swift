import Foundation

public struct EvaluationContext: Sendable {
    public var values: [String: Int]
    public var roundEntries: [ScoreEntry]
    public var roundNumber: Int
    public var playerCount: Int

    public init(
        values: [String: Int],
        roundEntries: [ScoreEntry] = [],
        roundNumber: Int = 1,
        playerCount: Int
    ) {
        self.values = values
        self.roundEntries = roundEntries
        self.roundNumber = roundNumber
        self.playerCount = playerCount
    }
}

public enum ExpressionError: Error, Equatable, LocalizedError {
    case missingValue(String)
    case invalidArity(ExpressionOperation)
    case divisionByZero
    case numericOverflow
    case complexityLimit

    public var errorDescription: String? {
        switch self {
        case .missingValue(let name): "Missing value for \(name)."
        case .invalidArity(let operation): "Invalid arguments for \(operation.rawValue)."
        case .divisionByZero: "Division by zero is not allowed."
        case .numericOverflow: "The score is outside the supported numeric range."
        case .complexityLimit: "The expression is too complex."
        }
    }
}

public struct ExpressionEvaluator: Sendable {
    public let maximumDepth: Int

    public init(maximumDepth: Int = 24) {
        self.maximumDepth = maximumDepth
    }

    public func evaluate(_ expression: Expression, context: EvaluationContext) throws -> Int {
        try evaluate(expression, context: context, depth: 0)
    }

    private func evaluate(_ expression: Expression, context: EvaluationContext, depth: Int) throws -> Int {
        guard depth <= maximumDepth else { throw ExpressionError.complexityLimit }
        let values = try expression.arguments.map { try evaluate($0, context: context, depth: depth + 1) }

        switch expression.operation {
        case .constant:
            guard let value = expression.value else { throw ExpressionError.invalidArity(.constant) }
            return value
        case .field:
            guard let field = expression.field else { throw ExpressionError.invalidArity(.field) }
            guard let value = context.values[field] else { throw ExpressionError.missingValue(field) }
            return value
        case .roundNumber:
            return context.roundNumber
        case .playerCount:
            return context.playerCount
        case .add:
            return try values.reduce(0) { try checkedAdd($0, $1) }
        case .subtract:
            guard let first = values.first, values.count >= 2 else { throw ExpressionError.invalidArity(.subtract) }
            return try values.dropFirst().reduce(first) { try checkedSubtract($0, $1) }
        case .multiply:
            return try values.reduce(1) { try checkedMultiply($0, $1) }
        case .divide:
            guard values.count == 2 else { throw ExpressionError.invalidArity(.divide) }
            guard values[1] != 0 else { throw ExpressionError.divisionByZero }
            guard values[0] != Int.min || values[1] != -1 else { throw ExpressionError.numericOverflow }
            return values[0] / values[1]
        case .abs:
            guard values.count == 1 else { throw ExpressionError.invalidArity(.abs) }
            guard values[0] != Int.min else { throw ExpressionError.numericOverflow }
            return Swift.abs(values[0])
        case .min:
            guard let result = values.min() else { throw ExpressionError.invalidArity(.min) }
            return result
        case .max:
            guard let result = values.max() else { throw ExpressionError.invalidArity(.max) }
            return result
        case .equals:
            guard values.count == 2 else { throw ExpressionError.invalidArity(.equals) }
            return values[0] == values[1] ? 1 : 0
        case .greaterThan:
            guard values.count == 2 else { throw ExpressionError.invalidArity(.greaterThan) }
            return values[0] > values[1] ? 1 : 0
        case .lessThan:
            guard values.count == 2 else { throw ExpressionError.invalidArity(.lessThan) }
            return values[0] < values[1] ? 1 : 0
        case .if:
            guard values.count == 3 else { throw ExpressionError.invalidArity(.if) }
            return values[0] != 0 ? values[1] : values[2]
        case .sum:
            if let field = expression.field {
                return try context.roundEntries.reduce(0) { try checkedAdd($0, $1.values[field] ?? 0) }
            }
            return try values.reduce(0) { try checkedAdd($0, $1) }
        case .count:
            if let field = expression.field {
                return context.roundEntries.reduce(0) { $0 + ($1.values[field] == nil ? 0 : 1) }
            }
            return values.count
        }
    }

    private func checkedAdd(_ lhs: Int, _ rhs: Int) throws -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        guard !result.overflow else { throw ExpressionError.numericOverflow }
        return result.partialValue
    }

    private func checkedSubtract(_ lhs: Int, _ rhs: Int) throws -> Int {
        let result = lhs.subtractingReportingOverflow(rhs)
        guard !result.overflow else { throw ExpressionError.numericOverflow }
        return result.partialValue
    }

    private func checkedMultiply(_ lhs: Int, _ rhs: Int) throws -> Int {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        guard !result.overflow else { throw ExpressionError.numericOverflow }
        return result.partialValue
    }
}
