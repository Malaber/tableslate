# TableSlate

TableSlate is a native, offline-first iPhone and iPad tabletop scoring companion. It keeps score entry fast while treating every supported game as a versioned declarative definition rather than hard-coded UI.

## Included in the first implementation

- Wizard round scoring, trick-total validation, editable rounds, standings, ties, and recovery
- Cascadia final score form with grouped categories and automatic totals
- Generic score sheets with per-round or direct-total scoring and highest/lowest-wins modes
- reusable players, favorites, recents, multiple active games, undo, auto-save, history, and derived results
- safe local `.tableslate-game.json` import with schema, size, identifier, complexity, and version checks
- system, light, and dark appearance settings using the graphite-and-mint app identity
- responsive iPhone/iPad SwiftUI layouts, Dynamic Type, VoiceOver labels, and UI-test identifiers
- a pure Swift `TableSlateCore`, generated Xcode project, CI scaffolding, privacy manifest, and static website

No account, backend, analytics, advertising, or tracking is used.

## Develop

Requirements: Swift 6, Xcode 26+, XcodeGen, Python 3.11+, and Invoke.

```bash
python3 -m venv .venv
.venv/bin/pip install -e .
.venv/bin/inv generate-ios-project
.venv/bin/inv check-ios-package
.venv/bin/inv build-ios-simulator
```

The generated `TableSlateApp.xcodeproj` is ignored. [`ios/TableSlateIOS/project.yml`](ios/TableSlateIOS/project.yml) is authoritative.

Architecture and definition authoring are documented in [`docs/architecture.md`](docs/architecture.md) and [`docs/game-definition-format.md`](docs/game-definition-format.md).
