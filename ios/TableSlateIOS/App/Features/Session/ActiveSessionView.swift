import SwiftUI
import TableSlateCore
import UIKit

struct ActiveSessionView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingAbandonConfirmation = false
    @State private var completed = false
    let sessionID: UUID

    var body: some View {
        Group {
            if let session = store.session(id: sessionID) {
                renderer(for: session)
                    .navigationTitle(session.definitionSnapshot.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { sessionToolbar(session) }
            } else if let session = store.completedSession(id: sessionID) {
                CompletedSessionView(session: session, closeAction: { dismiss() })
            } else {
                EmptyState(icon: "questionmark.folder", title: "Game unavailable", message: "This session is no longer active.")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            }
        }
        .confirmationDialog(
            "Abandon this game?",
            isPresented: $showingAbandonConfirmation,
            titleVisibility: .visible
        ) {
            Button("Abandon Game", role: .destructive) {
                store.abandonSession(id: sessionID)
                dismiss()
            }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("This removes the unfinished score sheet. Completed games are not affected.")
        }
    }

    @ViewBuilder
    private func renderer(for session: GameSession) -> some View {
        switch session.definitionSnapshot.layout.renderer {
        case .roundTable:
            RoundTableView(session: session, onComplete: complete)
        case .scoreForm:
            ScoreFormView(session: session, onComplete: complete)
        case .scoreCounter:
            ScoreCounterView(session: session, onComplete: complete)
        }
    }

    @ToolbarContentBuilder
    private func sessionToolbar(_ session: GameSession) -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { store.undo(sessionID: session.id) } label: { Image(systemName: "arrow.uturn.backward") }
                .disabled(!store.canUndo(sessionID: session.id))
                .accessibilityLabel("Undo last score change")
                .accessibilityIdentifier("undo-score")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { complete() } label: { Label("End Game", systemImage: "checkered.flag") }
                Button(role: .destructive) { showingAbandonConfirmation = true } label: {
                    Label("Abandon Game", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Session actions")
        }
    }

    private func complete() {
        store.completeSession(id: sessionID)
        completed = true
    }
}

private struct RoundTableView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingRounds = false
    let session: GameSession
    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                roundHeader
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 18) {
                        entryColumn.frame(minWidth: 520)
                        standings.frame(minWidth: 280, maxWidth: 380)
                    }
                    VStack(spacing: 18) {
                        entryColumn
                        standings
                    }
                }
                Button { showingRounds = true } label: {
                    Label("View and edit previous rounds", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
                PrimaryButton(title: isLastRound ? "Finish Game" : "Next Round", icon: isLastRound ? "checkered.flag" : "arrow.right") {
                    if isLastRound { onComplete() } else { store.advanceRound(sessionID: session.id) }
                }
                .accessibilityIdentifier("next-round-button")
            }
            .padding()
        }
        .slateBackground()
        .sheet(isPresented: $showingRounds) {
            NavigationStack { RoundHistoryEditor(sessionID: session.id) }
                .environmentObject(store)
        }
    }

    private var roundHeader: some View {
        VStack(spacing: 10) {
            Text("ROUND \(session.currentRound) OF \(maximumRounds)")
                .font(.caption.weight(.black))
                .tracking(1.4)
                .foregroundStyle(SlateTheme.deepMint)
            Text("Enter bids and tricks")
                .font(.title.bold())
            validationBanner
        }
        .frame(maxWidth: .infinity)
    }

    private var entryColumn: some View {
        VStack(spacing: 12) {
            ForEach(session.players) { player in
                WizardPlayerEntry(session: session, player: player, round: session.currentRound)
            }
        }
        .frame(maxWidth: 680)
    }

    private var standings: some View {
        SlateCard {
            SectionHeader(title: "Standings", subtitle: "Through the values entered so far")
            ForEach(store.results(for: session)) { result in RankingRow(result: result) }
        }
    }

    @ViewBuilder
    private var validationBanner: some View {
        let trickTotal = session.scoreEntries
            .filter { $0.roundNumber == session.currentRound }
            .reduce(0) { $0 + ($1.values["tricks"] ?? 0) }
        let warnings = store.validation(forRound: session.currentRound, session: session)
        if case .warning(let message, _) = warnings.first {
            ValidationBanner(text: "\(trickTotal) / \(session.currentRound) tricks · \(message)", isInvalid: true)
                .accessibilityIdentifier("round-validation-warning")
        } else {
            ValidationBanner(text: "\(trickTotal) / \(session.currentRound) tricks entered")
        }
    }

    private var maximumRounds: Int { store.maximumRounds(for: session) ?? session.currentRound }
    private var isLastRound: Bool { session.currentRound >= maximumRounds }
}

private struct WizardPlayerEntry: View {
    @EnvironmentObject private var store: AppStore
    let session: GameSession
    let player: SessionPlayer
    let round: Int

    var body: some View {
        SlateCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PlayerChip(name: player.name, selected: true)
                    Spacer()
                    if let score {
                        Text(score, format: .number)
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(score >= 0 ? SlateTheme.deepMint : Color.orange)
                            .accessibilityLabel("Round score \(score)")
                    }
                }
                ForEach(session.definitionSnapshot.inputs) { input in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(input.label).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                        QuickValueRow(
                            values: input.quickValues.isEmpty ? defaultQuickValues : input.quickValues,
                            selection: store.valueIfPresent(sessionID: session.id, playerID: player.id, field: input.id, round: round),
                            accessibilityPrefix: "\(player.name)-\(input.id)"
                        ) { value in
                            store.setValue(sessionID: session.id, playerID: player.id, field: input.id, round: round, value: value)
                        }
                    }
                }
            }
        }
    }

    private var defaultQuickValues: [Int] { Array(0...max(1, min(round, 20))) }

    private var score: Int? {
        guard let entry = session.scoreEntries.first(where: { $0.playerID == player.id && $0.roundNumber == round }),
              session.definitionSnapshot.inputs.allSatisfy({ entry.values[$0.id] != nil }) else { return nil }
        return store.entryScore(entry, session: session)
    }
}

private struct QuickValueRow: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    let values: [Int]
    let selection: Int?
    let accessibilityPrefix: String
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(values, id: \.self) { value in
                    Button {
                        onSelect(value)
                        if hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    } label: {
                        Text(value, format: .number)
                            .font(.headline.monospacedDigit())
                            .frame(minWidth: 44, minHeight: 44)
                            .background(selection == value ? SlateTheme.mint : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(selection == value ? SlateTheme.graphite : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(accessibilityPrefix), \(value)")
                    .accessibilityIdentifier("\(accessibilityPrefix)-\(value)")
                }
            }
        }
    }
}

private struct RoundHistoryEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRound = 1
    let sessionID: UUID

    var body: some View {
        Group {
            if let session = store.session(id: sessionID) {
                ScrollView {
                    VStack(spacing: 14) {
                        Picker("Round", selection: $selectedRound) {
                            ForEach(1...session.currentRound, id: \.self) { Text("Round \($0)").tag($0) }
                        }
                        .pickerStyle(.menu)
                        ForEach(session.players) { player in
                            WizardPlayerEntry(session: session, player: player, round: selectedRound)
                        }
                    }
                    .padding()
                }
                .slateBackground()
                .navigationTitle("Edit Rounds")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            }
        }
    }
}

private struct ScoreFormView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var playerIndex = 0
    let session: GameSession
    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                playerPicker
                if horizontalSizeClass == .regular {
                    HStack(alignment: .top, spacing: 18) {
                        fields
                        standings.frame(minWidth: 300, maxWidth: 400)
                    }
                } else {
                    fields
                    standings
                }
                PrimaryButton(title: "Finish Game", icon: "checkered.flag", action: onComplete)
                    .accessibilityIdentifier("finish-game-button")
            }
            .padding()
        }
        .slateBackground()
    }

    private var selectedPlayer: SessionPlayer { session.players[min(playerIndex, session.players.count - 1)] }

    private var playerPicker: some View {
        Picker("Player", selection: $playerIndex) {
            ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                Text(player.name).tag(index)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("score-form-player-picker")
    }

    private var fields: some View {
        VStack(spacing: 16) {
            ForEach(groups, id: \.self) { group in
                SlateCard {
                    SectionHeader(title: group)
                    ForEach(session.definitionSnapshot.inputs.filter { ($0.group ?? "Score") == group }) { input in
                        ScoreField(
                            label: input.label,
                            value: store.value(sessionID: session.id, playerID: selectedPlayer.id, field: input.id, round: nil),
                            allowsNegative: input.allowsNegative,
                            minimum: input.minimum,
                            maximum: input.maximum,
                            identifier: "\(selectedPlayer.name)-\(input.id)"
                        ) { value in
                            store.setValue(sessionID: session.id, playerID: selectedPlayer.id, field: input.id, round: nil, value: value)
                        }
                        Divider()
                    }
                    HStack {
                        Text("Subtotal")
                            .font(.headline)
                        Spacer()
                        Text(subtotal(for: group), format: .number)
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(SlateTheme.deepMint)
                            .accessibilityLabel("\(group) subtotal, \(subtotal(for: group))")
                    }
                    .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: 680)
    }

    private var standings: some View {
        SlateCard {
            SectionHeader(title: "Totals")
            ForEach(store.results(for: session)) { result in RankingRow(result: result) }
        }
    }

    private var groups: [String] {
        session.definitionSnapshot.inputs.reduce(into: [String]()) { result, input in
            let group = input.group ?? "Score"
            if !result.contains(group) { result.append(group) }
        }
    }

    private func subtotal(for group: String) -> Int {
        session.definitionSnapshot.inputs
            .filter { ($0.group ?? "Score") == group }
            .reduce(0) { total, input in
                let value = store.value(
                    sessionID: session.id,
                    playerID: selectedPlayer.id,
                    field: input.id,
                    round: nil
                )
                let result = total.addingReportingOverflow(value)
                return result.overflow ? (value >= 0 ? Int.max : Int.min) : result.partialValue
            }
    }
}

private struct ScoreCounterView: View {
    @EnvironmentObject private var store: AppStore
    @State private var editingPlayer: SessionPlayer?
    let session: GameSession
    let onComplete: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 4) {
                    Text(directMode ? "CURRENT TOTALS" : "ROUND \(session.currentRound)")
                        .font(.caption.weight(.black)).tracking(1.4).foregroundStyle(SlateTheme.deepMint)
                    Text(highestWins ? "Highest score wins" : "Lowest score wins")
                        .font(.title2.bold())
                }
                ForEach(session.players) { player in
                    SlateCard {
                        HStack(spacing: 14) {
                            PlayerChip(name: player.name, selected: true)
                            Spacer()
                            Button { change(player, by: -1) } label: {
                                Image(systemName: "minus").frame(width: 44, height: 44)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Subtract one from \(player.name)")
                            .accessibilityIdentifier("decrement-\(player.name)")
                            Button { editingPlayer = player } label: {
                                Text(displayedScore(for: player), format: .number)
                                    .font(.title.bold().monospacedDigit())
                                    .frame(minWidth: 70, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(player.name) score, \(displayedScore(for: player))")
                            .accessibilityIdentifier("score-\(player.name)")
                            Button { change(player, by: 1) } label: {
                                Image(systemName: "plus").frame(width: 44, height: 44)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(SlateTheme.mint)
                            .foregroundStyle(SlateTheme.graphite)
                            .accessibilityLabel("Add one to \(player.name)")
                            .accessibilityIdentifier("increment-\(player.name)")
                        }
                    }
                }
                SlateCard {
                    SectionHeader(title: "Standings")
                    ForEach(store.results(for: session)) { RankingRow(result: $0) }
                }
                PrimaryButton(title: directMode ? "Finish Game" : "Next Round", icon: directMode ? "checkered.flag" : "arrow.right") {
                    directMode ? onComplete() : store.advanceRound(sessionID: session.id)
                }
                .accessibilityIdentifier(directMode ? "finish-game-button" : "next-round-button")
            }
            .padding()
        }
        .slateBackground()
        .sheet(item: $editingPlayer) { player in
            NumericEntrySheet(
                title: player.name,
                value: store.value(sessionID: session.id, playerID: player.id, field: scoreField, round: entryRound),
                allowsNegative: allowsNegative
            ) { value in
                store.setValue(sessionID: session.id, playerID: player.id, field: scoreField, round: entryRound, value: value)
            }
            .presentationDetents([.medium])
        }
    }

    private var directMode: Bool {
        session.definitionSnapshot.session.type == .continuousScore
            || session.configuration["scoringMode"] == 1
    }
    private var highestWins: Bool {
        session.configuration["highestWins"].map { $0 != 0 }
            ?? session.definitionSnapshot.resultRules.highestWins
    }
    private var entryRound: Int? { directMode ? nil : session.currentRound }
    private var scoreField: String { session.definitionSnapshot.inputs.first?.id ?? "score" }
    private var allowsNegative: Bool { session.definitionSnapshot.inputs.first?.allowsNegative ?? true }

    private func displayedScore(for player: SessionPlayer) -> Int {
        if directMode {
            return store.value(sessionID: session.id, playerID: player.id, field: scoreField, round: nil)
        }
        return store.results(for: session).first { $0.playerID == player.id }?.score ?? 0
    }

    private func change(_ player: SessionPlayer, by delta: Int) {
        store.addValue(sessionID: session.id, playerID: player.id, field: scoreField, round: entryRound, delta: delta)
    }
}

private struct ScoreField: View {
    @State private var showingEntry = false
    let label: String
    let value: Int
    let allowsNegative: Bool
    let minimum: Int?
    let maximum: Int?
    let identifier: String
    let onChange: (Int) -> Void

    var body: some View {
        HStack {
            Text(label).font(.body.weight(.medium))
            Spacer()
            Button { onChange(clamp(value - 1)) } label: {
                Image(systemName: "minus").frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Subtract one from \(label)")
            .accessibilityIdentifier("\(identifier)-minus")
            Button { showingEntry = true } label: {
                Text(value, format: .number)
                    .font(.title3.bold().monospacedDigit())
                    .frame(minWidth: 58, minHeight: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(label), \(value)")
            .accessibilityIdentifier("\(identifier)-value")
            Button { onChange(clamp(value + 1)) } label: {
                Image(systemName: "plus").frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Add one to \(label)")
            .accessibilityIdentifier("\(identifier)-plus")
        }
        .padding(.vertical, 5)
        .sheet(isPresented: $showingEntry) {
            NumericEntrySheet(title: label, value: value, allowsNegative: allowsNegative) { onChange(clamp($0)) }
                .presentationDetents([.medium])
        }
    }

    private func clamp(_ candidate: Int) -> Int {
        max(minimum ?? Int.min, min(maximum ?? Int.max, candidate))
    }
}

private struct NumericEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var text: String
    let title: String
    let allowsNegative: Bool
    let onDone: (Int) -> Void

    init(title: String, value: Int, allowsNegative: Bool, onDone: @escaping (Int) -> Void) {
        self.title = title
        self.allowsNegative = allowsNegative
        self.onDone = onDone
        _text = State(initialValue: String(value))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text(Int(text) ?? 0, format: .number)
                    .font(.system(size: 46, weight: .bold, design: .rounded).monospacedDigit())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9], id: \.self) { digit in key(String(digit)) { append(digit) } }
                    key(allowsNegative ? "−" : "Clear") { allowsNegative ? toggleSign() : clear() }
                    key("0") { append(0) }
                    key("⌫") { backspace() }
                }
                PrimaryButton(title: "Done", icon: "checkmark") {
                    onDone(Int(text) ?? 0)
                    dismiss()
                }
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .slateBackground()
        }
    }

    private func key(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.title2.bold()).frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    private func append(_ digit: Int) {
        if text == "0" { text = "" }
        if text.count < 8 { text.append(String(digit)) }
        tap()
    }

    private func toggleSign() {
        text = text.hasPrefix("-") ? String(text.dropFirst()) : "-" + text
        tap()
    }

    private func clear() { text = "0"; tap() }
    private func backspace() { if !text.isEmpty { text.removeLast() }; if text.isEmpty || text == "-" { text = "0" }; tap() }
    private func tap() { if hapticsEnabled { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
}
