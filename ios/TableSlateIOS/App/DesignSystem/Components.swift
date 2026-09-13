import SwiftUI
import TableSlateCore

struct SlateCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(SlateTheme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.primary.opacity(0.07))
            }
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.weight(.bold))
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct PrimaryButton: View {
    let title: String
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon ?? "arrow.right")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(SlateTheme.mint)
        .foregroundStyle(SlateTheme.graphite)
        .controlSize(.large)
    }
}

struct GameCard: View {
    let definition: GameDefinition
    let favorite: Bool

    var body: some View {
        SlateCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(SlateTheme.mint)
                    .frame(width: 48, height: 48)
                    .background(SlateTheme.mint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(definition.name).font(.headline)
                        if favorite { Image(systemName: "star.fill").foregroundStyle(SlateTheme.mint) }
                    }
                    Text("\(definition.players.minimum)–\(definition.players.maximum) players · \(styleName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch definition.layout.renderer {
        case .roundTable: "list.number"
        case .scoreForm: "checklist"
        case .scoreCounter: "plusminus"
        }
    }

    private var styleName: String {
        switch definition.session.type {
        case .roundBased: "Rounds"
        case .finalScore: "Final score"
        case .continuousScore: "Continuous"
        case .generic: "Flexible"
        }
    }
}

struct RankingRow: View {
    let result: PlayerResult

    var body: some View {
        HStack(spacing: 14) {
            Text("\(result.rank)")
                .font(.headline.monospacedDigit())
                .frame(width: 34, height: 34)
                .background(result.isWinner ? SlateTheme.mint : Color.secondary.opacity(0.14), in: Circle())
                .foregroundStyle(result.isWinner ? SlateTheme.graphite : .primary)
            Text(result.playerName).font(.headline)
            if result.isWinner {
                Text("Winner").font(.caption.weight(.bold)).foregroundStyle(SlateTheme.deepMint)
            }
            Spacer()
            Text(result.score, format: .number)
                .font(.title3.bold().monospacedDigit())
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(result.rank), \(result.playerName), \(result.score) points\(result.isWinner ? ", winner" : "")")
    }
}

struct ValidationBanner: View {
    let text: String
    var isInvalid = false

    var body: some View {
        Label(text, systemImage: isInvalid ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .foregroundStyle(isInvalid ? Color.orange : SlateTheme.deepMint)
            .background((isInvalid ? Color.orange : SlateTheme.mint).opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(message))
            .symbolRenderingMode(.hierarchical)
    }
}

struct SettingsToolbarButton: View {
    @Binding var showingSettings: Bool

    var body: some View {
        Button { showingSettings = true } label: {
            Image(systemName: "gearshape.fill")
        }
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("settings-button")
    }
}
