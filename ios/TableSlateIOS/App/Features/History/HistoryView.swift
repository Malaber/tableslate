import SwiftUI
import TableSlateCore

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var showingSettings: Bool

    var body: some View {
        NavigationStack {
            Group {
                if store.completedSessions.isEmpty {
                    EmptyState(
                        icon: "clock",
                        title: "No finished games",
                        message: "Completed score sheets and results will appear here."
                    )
                } else {
                    List(store.completedSessions) { session in
                        NavigationLink {
                            CompletedSessionView(session: session)
                        } label: {
                            HistoryRow(session: session)
                        }
                        .listRowBackground(SlateTheme.card)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .slateBackground()
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsToolbarButton(showingSettings: $showingSettings)
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let session: GameSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.definitionSnapshot.name).font(.headline)
                Spacer()
                if let completedAt = session.completedAt {
                    Text(completedAt, format: .dateTime.day().month(.abbreviated).year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(session.players.map(\.name).joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let winners = winnerNames {
                Label("\(winners) won", systemImage: "trophy.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SlateTheme.deepMint)
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }

    private var winnerNames: String? {
        let winners = session.calculatedResults.filter(\.isWinner).map(\.playerName)
        return winners.isEmpty ? nil : winners.joined(separator: " & ")
    }
}

struct CompletedSessionView: View {
    @Environment(\.dismiss) private var dismiss
    let session: GameSession
    var closeAction: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                SlateCard {
                    VStack(spacing: 8) {
                        Image(systemName: session.calculatedResults.filter(\.isWinner).count > 1 ? "person.2.fill" : "trophy.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(SlateTheme.mint)
                        Text(resultHeadline).font(.title.bold()).multilineTextAlignment(.center)
                        Text(completionDescription).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                SlateCard {
                    SectionHeader(title: "Final ranking")
                    ForEach(session.calculatedResults) { RankingRow(result: $0) }
                }
                scoreSheet
                if let closeAction {
                    PrimaryButton(title: "Done", icon: "checkmark", action: closeAction)
                }
            }
            .padding()
        }
        .slateBackground()
        .navigationTitle(session.definitionSnapshot.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var scoreSheet: some View {
        SlateCard {
            SectionHeader(title: "Score sheet", subtitle: "Definition v\(session.definitionVersion) is preserved with this game")
            if session.definitionSnapshot.session.type == .roundBased {
                ForEach(1...max(1, session.scoreEntries.compactMap(\.roundNumber).max() ?? 1), id: \.self) { round in
                    DisclosureGroup("Round \(round)") {
                        ForEach(session.players) { player in
                            if let entry = session.scoreEntries.first(where: { $0.playerID == player.id && $0.roundNumber == round }) {
                                HStack {
                                    Text(player.name)
                                    Spacer()
                                    Text(entry.values.map { "\($0.key.capitalized): \($0.value)" }.sorted().joined(separator: " · "))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
            } else {
                ForEach(session.players) { player in
                    DisclosureGroup(player.name) {
                        if let entry = session.scoreEntries.first(where: { $0.playerID == player.id }) {
                            ForEach(session.definitionSnapshot.inputs) { input in
                                HStack {
                                    Text(input.label)
                                    Spacer()
                                    Text(entry.values[input.id] ?? 0, format: .number).monospacedDigit()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
    }

    private var resultHeadline: String {
        let winners = session.calculatedResults.filter(\.isWinner).map(\.playerName)
        if winners.count == 1 { return "\(winners[0]) wins!" }
        if !winners.isEmpty { return "Tie: \(winners.joined(separator: " & "))" }
        return "Game complete"
    }

    private var completionDescription: String {
        guard let completed = session.completedAt else { return "Completed game" }
        let duration = completed.timeIntervalSince(session.startedAt)
        let formatted = Duration.seconds(duration).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
        return "\(completed.formatted(date: .abbreviated, time: .shortened)) · \(formatted)"
    }
}
