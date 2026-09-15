# Game-definition format

TableSlate game files use the suffix `.tableslate-game.json`. The current schema version is `1`.

## Minimal shape

```json
{
  "schemaVersion": 1,
  "id": "example-game",
  "definitionVersion": 1,
  "name": "Example Game",
  "aliases": [],
  "players": { "minimum": 2, "maximum": 6 },
  "session": { "type": "generic" },
  "layout": { "renderer": "scoreCounter" },
  "inputs": [
    {
      "id": "score",
      "label": "Score",
      "allowsNegative": true,
      "quickValues": [-5, -1, 1, 5]
    }
  ],
  "scoreRules": {
    "entryScore": {
      "operation": "field",
      "field": "score",
      "arguments": []
    }
  },
  "validationRules": [],
  "resultRules": { "highestWins": true },
  "source": { "author": "Your Name", "isBuiltIn": false }
}
```

Identifiers use lowercase ASCII letters, numbers, and single hyphens. Supported session types are `roundBased`, `finalScore`, `continuousScore`, and `generic`. Supported renderers are `roundTable`, `scoreForm`, and `scoreCounter`.

Inputs may include `group`, `minimum`, `maximum`, `allowsNegative`, and `quickValues`. A definition can contain at most 64 inputs.

Round progression may define `maximumRounds` and `endWhenAnyScoreReaches` expressions. The latter ends a round-based game when any cumulative player score meets or exceeds the evaluated positive threshold; SKYJO uses `100`.

## Safe expressions

Every expression is a JSON tree with an `operation`, zero or more `arguments`, and operation-specific `value` or `field` data. Schema v1 supports:

```text
add subtract multiply divide abs min max
equals greaterThan lessThan if sum count
field constant roundNumber playerCount
```

Boolean operations return `1` for true and `0` for false. `if` takes condition, true value, and false value. `sum` with a `field` totals that field across the current round; without one, it totals its arguments. Division by zero is rejected at evaluation time.

Imported expressions are bounded to 24 levels and 256 nodes. Definitions cannot contain Swift, JavaScript, HTML, scripts, or behavior-controlling URLs.

Wizard’s built-in file is the canonical example of conditional round scoring and aggregate validation.
