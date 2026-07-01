import SwiftUI

/// Routes an existing entry to the right detail screen:
/// - **Upcoming** → a read-only plan view with the AI pre-comment (if any)
///   and a prominent "Add result" affordance that opens `MatchAddResultView`.
/// - **Completed** → the full `MatchJournalEntryView` editor, which now also
///   renders the stored AI report at the top.
///
/// We re-read the entry from the manager by id so it stays fresh after an
/// "Add result" round-trip flips it to completed.
struct MatchDetailView: View {
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var lang: LanguageManager

    let entryID: String

    private var entry: MatchEntry? { matches.entry(withID: entryID) }

    var body: some View {
        Group {
            if let entry {
                if entry.status == .upcoming {
                    UpcomingDetail(entry: entry)
                } else {
                    MatchJournalEntryView(entry: entry)
                }
            } else {
                // Entry was deleted out from under us — show nothing.
                Color.clear
            }
        }
    }

    // MARK: - Upcoming detail

    private struct UpcomingDetail: View {
        @EnvironmentObject private var matches: MatchEntryManager
        @EnvironmentObject private var lang: LanguageManager

        let entry: MatchEntry
        @State private var showAddResult = false
        @State private var showMentalCheck = false
        @State private var showDeleteConfirm = false
        @Environment(\.dismiss) private var dismiss
        @EnvironmentObject private var session: UserSessionManager

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if !entry.preMatchNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        planCard
                    }
                    if let comment = entry.aiPreComment?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !comment.isEmpty {
                        MatchAnalysisCard(title: lang.t("matches.ai_pre_title"), report: comment)
                    }
                    mentalCheckButton
                    addResultButton
                    deleteButton
                }
                .padding(20)
            }
            .background(AppPalette.cream)
            .navigationTitle(lang.t("matches.upcoming_title"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showAddResult) {
                NavigationStack {
                    MatchAddResultView(entry: entry)
                        .environmentObject(matches)
                        .environmentObject(lang)
                }
            }
            .sheet(isPresented: $showMentalCheck) {
                NavigationStack {
                    MentalCheckView()
                        .environmentObject(lang)
                        .environmentObject(session)
                }
            }
            .confirmationDialog(
                lang.t("matches.delete_title"),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(lang.t("common.delete"), role: .destructive) {
                    matches.delete(entry.id)
                    dismiss()
                }
                Button(lang.t("common.cancel"), role: .cancel) {}
            }
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.white)
                    Text(upcomingBadge)
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Text(displayedOpponent)
                    .appFont(22, weight: .heavy)
                    .foregroundStyle(.white)
                if let tournament = entry.displayTournament {
                    Label(tournament, systemImage: "trophy.fill")
                        .font(.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Text(dateDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            // "Hero + select cards": the upcoming match header band becomes a
            // PhotoMatch hero; foreground flips to white over the duotone scrim.
            .brandedPhoto("PhotoMatch", scrim: .hero, cornerRadius: 18)
        }

        private var planCard: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(lang.t("matches.pre_match_label"))
                    .font(.caption.weight(.heavy))
                    .tracking(0.6)
                    .foregroundStyle(AppPalette.inkSoft)
                    .textCase(.uppercase)
                Text(entry.preMatchNotes)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }

        private var mentalCheckButton: some View {
            Button {
                Haptics.tap()
                showMentalCheck = true
            } label: {
                Label(lang.t("mental.shortcut_title"), systemImage: "brain.head.profile")
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.clay)
        }

        private var addResultButton: some View {
            Button {
                Haptics.tap()
                showAddResult = true
            } label: {
                Label(lang.t("matches.add_result_cta"), systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
        }

        private var deleteButton: some View {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label(lang.t("common.delete"), systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.alert)
        }

        private var upcomingBadge: String { lang.t("matches.upcoming_badge") }

        private var displayedOpponent: String {
            let t = entry.opponentName.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? lang.t("matches.unknown_opponent") : t
        }

        private var dateDisplay: String {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .short
            return f.string(from: entry.date)
        }
    }
}
