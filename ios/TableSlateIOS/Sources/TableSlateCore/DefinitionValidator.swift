import Foundation

public enum DefinitionValidationError: Error, Equatable, LocalizedError {
    case unsupportedSchema(Int)
    case invalidIdentifier
    case invalidDefinition
    case invalidPlayerRange
    case invalidInput(String)
    case tooManyInputs
    case duplicateInput(String)
    case duplicateValidationRule(String)
    case invalidExpressionField(String)
    case invalidExpressionShape(ExpressionOperation)
    case expressionTooComplex

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version): "Schema version \(version) is not supported."
        case .invalidIdentifier: "The game identifier is invalid."
        case .invalidDefinition: "The game definition is incomplete."
        case .invalidPlayerRange: "The supported player range is invalid."
        case .invalidInput(let id): "The input field \(id) is invalid."
        case .tooManyInputs: "The definition contains too many fields."
        case .duplicateInput(let id): "The input identifier \(id) is duplicated."
        case .duplicateValidationRule(let id): "The validation rule identifier \(id) is duplicated."
        case .invalidExpressionField(let id): "The scoring expression references unknown field \(id)."
        case .invalidExpressionShape(let operation): "The \(operation.rawValue) expression has invalid arguments."
        case .expressionTooComplex: "A scoring expression is too complex."
        }
    }
}

public struct DefinitionValidator: Sendable {
    public let maximumInputs: Int
    public let maximumExpressionNodes: Int
    public let maximumExpressionDepth: Int

    public init(maximumInputs: Int = 64, maximumExpressionNodes: Int = 256, maximumExpressionDepth: Int = 24) {
        self.maximumInputs = maximumInputs
        self.maximumExpressionNodes = maximumExpressionNodes
        self.maximumExpressionDepth = maximumExpressionDepth
    }

    public func decodeAndValidate(_ data: Data, imported: Bool = true) throws -> GameDefinition {
        var definition = try JSONDecoder().decode(GameDefinition.self, from: data)
        if imported { definition.source.isBuiltIn = false }
        try validate(definition)
        return definition
    }

    public func validate(_ definition: GameDefinition) throws {
        guard definition.schemaVersion == 1 else {
            throw DefinitionValidationError.unsupportedSchema(definition.schemaVersion)
        }
        guard definition.definitionVersion >= 1,
              !definition.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !definition.inputs.isEmpty else {
            throw DefinitionValidationError.invalidDefinition
        }
        let identifier = /^[a-z0-9]+(?:-[a-z0-9]+)*$/
        guard definition.id.wholeMatch(of: identifier) != nil else {
            throw DefinitionValidationError.invalidIdentifier
        }
        guard definition.players.minimum >= 1,
              definition.players.maximum >= definition.players.minimum,
              definition.players.maximum <= 32 else {
            throw DefinitionValidationError.invalidPlayerRange
        }
        guard definition.inputs.count <= maximumInputs else { throw DefinitionValidationError.tooManyInputs }
        var inputIDs = Set<String>()
        for input in definition.inputs {
            guard input.id.wholeMatch(of: identifier) != nil,
                  !input.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  input.minimum == nil || input.maximum == nil || input.minimum! <= input.maximum!,
                  input.allowsNegative || (input.minimum ?? 0) >= 0,
                  input.quickValues.allSatisfy({ value in
                      (input.allowsNegative || value >= 0)
                          && (input.minimum.map { value >= $0 } ?? true)
                          && (input.maximum.map { value <= $0 } ?? true)
                  }) else {
                throw DefinitionValidationError.invalidInput(input.id)
            }
            guard inputIDs.insert(input.id).inserted else {
                throw DefinitionValidationError.duplicateInput(input.id)
            }
        }
        var validationRuleIDs = Set<String>()
        for rule in definition.validationRules {
            guard rule.id.wholeMatch(of: identifier) != nil,
                  !rule.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DefinitionValidationError.invalidDefinition
            }
            guard validationRuleIDs.insert(rule.id).inserted else {
                throw DefinitionValidationError.duplicateValidationRule(rule.id)
            }
        }
        let expressions = [definition.scoreRules.entryScore]
            + definition.validationRules.map(\.expression)
            + [
                definition.progression?.maximumRounds,
                definition.progression?.endWhenAnyScoreReaches,
            ].compactMap { $0 }
        for expression in expressions {
            let metrics = expressionMetrics(expression)
            guard metrics.nodes <= maximumExpressionNodes, metrics.depth <= maximumExpressionDepth else {
                throw DefinitionValidationError.expressionTooComplex
            }
            try validateExpression(expression, inputIDs: inputIDs)
        }
    }

    private func validateExpression(_ expression: Expression, inputIDs: Set<String>) throws {
        let count = expression.arguments.count
        let validShape: Bool
        switch expression.operation {
        case .constant:
            validShape = count == 0 && expression.value != nil && expression.field == nil
        case .field:
            validShape = count == 0 && expression.value == nil && expression.field != nil
        case .roundNumber, .playerCount:
            validShape = count == 0 && expression.value == nil && expression.field == nil
        case .add, .subtract, .multiply:
            validShape = count >= 2 && expression.value == nil && expression.field == nil
        case .divide, .equals, .greaterThan, .lessThan:
            validShape = count == 2 && expression.value == nil && expression.field == nil
        case .abs:
            validShape = count == 1 && expression.value == nil && expression.field == nil
        case .min, .max:
            validShape = count >= 1 && expression.value == nil && expression.field == nil
        case .if:
            validShape = count == 3 && expression.value == nil && expression.field == nil
        case .sum, .count:
            validShape = expression.value == nil
                && ((expression.field != nil && count == 0) || (expression.field == nil && count >= 1))
        }
        guard validShape else {
            throw DefinitionValidationError.invalidExpressionShape(expression.operation)
        }
        if let field = expression.field, !inputIDs.contains(field) {
            throw DefinitionValidationError.invalidExpressionField(field)
        }
        for argument in expression.arguments {
            try validateExpression(argument, inputIDs: inputIDs)
        }
    }

    private func expressionMetrics(_ expression: Expression, depth: Int = 1) -> (nodes: Int, depth: Int) {
        expression.arguments.reduce((nodes: 1, depth: depth)) { result, argument in
            let child = expressionMetrics(argument, depth: depth + 1)
            return (result.nodes + child.nodes, max(result.depth, child.depth))
        }
    }
}
