# TableSlate architecture

## Core rule

**TableSlate is a game-definition runtime, not a collection of individually coded score sheets.**

The application supplies reusable interaction primitives. A `GameDefinition` supplies rules. A `GameSession` supplies state. `ScoringEngine` supplies deterministic results.

```text
SwiftUI renderer
      ↓ mutations / presentation data
AppStore
      ↓
TableSlateCore
 ├─ DefinitionValidator
 ├─ ExpressionEvaluator
 ├─ ScoringEngine
 ├─ AppDataStore
 └─ Statistics
```

`TableSlateCore` imports Foundation but never SwiftUI. It owns models, safe expression evaluation, scoring, validation, ranking, definition snapshots, persistence, and derived statistics. SwiftUI owns navigation, layouts, the numeric keypad, haptics, import presentation, accessibility, and size-class adaptation.

## Definition and session lifecycle

Built-in definitions are ordinary JSON files under `ios/TableSlateIOS/Definitions/Builtin`. The app discovers these resources at runtime; adding a compatible built-in game requires no renderer or catalog edit.

Imported definitions pass the same decoder plus stricter source handling. They cannot replace built-ins, must increment their version when updated, and are limited in file size, field count, identifier shape, expression depth, and expression node count.

Starting a game copies the complete definition into `GameSession.definitionSnapshot`. All later scoring and history use that snapshot, so a definition update cannot rewrite old results.

## Persistence

Appearance, haptics, and the selected tab are tiny `UserDefaults` preferences. Players, active sessions, completed sessions, favorites, recents, and imported definitions live in versioned Codable JSON under Application Support.

Writes use atomic replacement after every meaningful score mutation. If decoding fails, the unreadable file is copied with a `corrupt-<timestamp>.json` suffix before a safe empty state is loaded and the user is informed.

## Renderer families

- `roundTable`: current-round input plus cumulative standings; Wizard uses quick-value chips.
- `scoreForm`: grouped final-score fields and per-player navigation; Cascadia uses this family.
- `scoreCounter`: direct totals or additive rounds with highest/lowest-wins configuration; SKYJO and Rommé use additive rounds.

The families interpret semantic hints but definitions never describe arbitrary SwiftUI trees.
