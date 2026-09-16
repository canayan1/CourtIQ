import SwiftUI

/// One line of the journal timeline. A match and a fuel entry are different
/// things and the row says which, rather than flattening both into a
/// generic "activity".
struct JournalItemRow: View {
    let item: JournalItem
    /// False inside a day sheet, which already names the date in its own
    /// heading — repeating it on every row is noise.
    var showsDate: Bool = true
    var onRateFuel: (NutritionEntry) -> Void
    var onOpenMatch: (MatchEntry) -> Void

    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        switch item {
        case .match(let m): matchRow(m)
        case .fuel(let n):  fuelRow(n)
        }
    }

    private func matchRow(_ m: MatchEntry) -> some View {
        Button {
            Haptics.tap()
            onOpenMatch(m)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: m.isUpcoming ? "calendar" : "figure.tennis")
                    .foregroundStyle(AppPalette.clay)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(showsDate ? dayLabel(m.date) : matchHeadline(m))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(matchSubtitle(m))
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                // The rest of the match UI writes the result as a bare W/L
                // badge; the journal says it the same way.
                if let result = m.result {
                    let won = result == .won
                    Text(won ? "W" : "L")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(won ? AppPalette.mossText : AppPalette.clayText)
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(won ? AppPalette.mossTint : AppPalette.clayTint, in: Capsule())
                        .accessibilityLabel(lang.t(won ? "journal.result_won" : "journal.result_lost"))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface(cornerRadius: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
    }

    /// Used when the date is already on the sheet: the opponent is the next
    /// most identifying thing about a match.
    private func matchHeadline(_ m: MatchEntry) -> String {
        let opponent = m.opponentName.trimmingCharacters(in: .whitespacesAndNewlines)
        return opponent.isEmpty ? lang.t(m.isUpcoming ? "journal.match_upcoming" : "journal.match_played") : opponent
    }

    private func matchSubtitle(_ m: MatchEntry) -> String {
        let opponent = m.opponentName.trimmingCharacters(in: .whitespacesAndNewlines)
        var parts: [String] = []
        // With the date hidden the opponent has moved up to the headline.
        if showsDate, !opponent.isEmpty { parts.append(opponent) }
        if !m.score.isEmpty { parts.append(m.score) }
        if let tournament = m.tournament?.trimmingCharacters(in: .whitespacesAndNewlines), !tournament.isEmpty {
            parts.append(tournament)
        }
        if parts.isEmpty { parts.append(lang.t(m.isUpcoming ? "journal.match_upcoming" : "journal.match_played")) }
        return parts.joined(separator: " · ")
    }

    private func fuelRow(_ n: NutritionEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: n.kind.symbol)
                .foregroundStyle(AppPalette.mossDeep)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(showsDate ? dayLabel(n.date) : lang.t(n.kind.labelKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text([showsDate ? lang.t(n.kind.labelKey) : nil,
                      n.timing.map { lang.t($0.labelKey) },
                      n.meal.map { lang.t($0.labelKey) },
                      lang.t(n.hydration.labelKey)]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = n.note, !note.isEmpty {
                    Text("“\(note)”")
                        .font(.caption.italic())
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            if let r = n.ratings {
                Button {
                    Haptics.tap()
                    onRateFuel(n)
                } label: {
                    Text(String(format: "%.1f", r.composite))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppPalette.mossDeep)
                        .monospacedDigit()
                }
                .buttonStyle(PressableCardStyle())
                .accessibilityLabel(String(format: lang.t("nutrition.rerate_a11y"), r.composite))
            } else {
                Button {
                    Haptics.tap()
                    onRateFuel(n)
                } label: {
                    Text(lang.t("nutrition.unrated"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.clayText)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(AppPalette.goldTint, in: Capsule())
                }
                .buttonStyle(PressableCardStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 16)
        // Delete lived only behind a long-press on the Nutrition screen, so a
        // mis-tap made from the Journal could not be undone from the Journal.
        .contextMenu {
            Button(role: .destructive) { NutritionManager.shared.delete(n.id) } label: {
                Label(lang.t("nutrition.delete"), systemImage: "trash")
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar(identifier: .iso8601)
        if cal.isDateInToday(date) { return lang.t("journal.day_today") }
        if cal.isDateInYesterday(date) { return lang.t("journal.day_yesterday") }
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.language.rawValue)
        f.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return f.string(from: date)
    }
}
