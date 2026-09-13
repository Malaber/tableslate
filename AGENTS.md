# TableSlate engineering rules

> **TableSlate is a game-definition runtime, not a collection of individually coded score sheets.**

- `TableSlateCore` owns definitions, expressions, scoring, validation, sessions, persistence models, and statistics. It must not import SwiftUI.
- The app owns navigation, renderers, input controls, accessibility, haptics, and Apple-framework integration.
- Built-in and imported games use the same declarative JSON schema and scoring engine.
- Never add executable code, HTML, arbitrary scripts, or behavior-controlling network URLs to game definitions.
- A completed session keeps its exact definition snapshot so history remains reproducible.
- Every meaningful score mutation must auto-save and remain undoable where practical.
- Keep `project.yml` authoritative; do not rely on hand-edited generated Xcode project state.
