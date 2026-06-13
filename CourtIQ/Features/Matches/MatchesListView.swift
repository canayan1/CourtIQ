import SwiftUI

/// Root view of the Matches tab. Lists every logged entry as a compact
/// row, with a floating "+" that opens a sheet asking the user to choose
/// between a Quick Log (30 seconds) or a full Journal entry. Empty state
/// invites the first log.
///
/// Design principle: almost no UI text — rows are visual (date + opponent
/// + W/L badge + surface icon), the "+" speaks for itself, and an empty
/// state uses a single illustration + a one-line nudge.
struct MatchesListView: View {
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager

    @State private var openNewEntry = false
    @State private var showTutorial = false

    /// One-shot flag so the tutorial auto-presents only on the first visit
    /// to the Matches tab. Re-openable any time via the (i) button.
    @AppStorage("CourtIQ.matchLogTutorialSeen.v1") private var tutorialSeen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                streakHeader
                if matches.entries.isEmpty {
                    emptyState
                } else {
                    insightShortcuts
                    MatchCalendarView()
                        .environmentObject(matches)
                        .environmentObject(lang)
                    entryList
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("tab.matches"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    Haptics.tap()
                    showTutorial = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                        .foregroundStyle(AppPalette.inkSoft)
                }
                .accessibilityLabel(lang.t("matches.tutorial.nav_title"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.tap()
                    openNewEntry = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppPalette.clay)
                }
                .accessibilityLabel(lang.t("matches.new_entry"))
            }
        }
        .onAppear {
            if !tutorialSeen {
                tutorialSeen = true
                // Defer so it doesn't fight the tab transition animation.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showTutorial = true
                }
            }
        }
        .sheet(isPresented: $showTutorial) {
            MatchLogTutorialView()
                .environmentObject(lang)
        }
        .sheet(isPresented: $openNewEntry) {
            NavigationStack {
                MatchEntryFlowView()
                    .environmentObject(matches)
                    .environmentObject(lang)
                    .environmentObject(session)
            }
        }
    }

    // MARK: - Streak header

    private var streakHeader: some View {
        HStack(spacing: 16) {
            LogStreakBadge(
                value: matches.currentStreak,
                graceActive: matches.streakGraceActive
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("\(matches.totalEntries)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                Text(lang.t("matches.total_logged"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            Spacer()
        }
        .padding(18)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Insight shortcut

    private var insightShortcuts: some View {
        NavigationLink {
            MatchTrendDashboardView()
                .environmentObject(matches)
                .environmentObject(lang)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundStyle(AppPalette.clay)
                    .frame(width: 28)
                Text(lang.t("matches.view_insights"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Entry list

    private var entryList: some View {
        VStack(spacing: 10) {
            ForEach(matches.entries) { entry in
                NavigationLink {
                    MatchDetailView(entryID: entry.id)
                        .environmentObject(matches)
                        .environmentObject(lang)
                        .environmentObject(session)
                } label: {
                    entryRow(entry)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func entryRow(_ entry: MatchEntry) -> some View {
        HStack(spacing: 14) {
            // Surface icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(surfaceColor(entry.surface))
                    .frame(width: 36, height: 48)
                Image(systemName: "scribble")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(displayedOpponent(entry))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .lineLimit(1)

                    if entry.isDraft {
                        draftBadge
                    } else if entry.status == .upcoming {
                        upcomingBadge
                    } else if let result = entry.result {
                        resultBadge(for: result)
                    }
                }

                Text(dateDisplay(entry.date))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }

            Spacer()

            if entry.aiReport != nil || entry.aiPreComment != nil {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func displayedOpponent(_ entry: MatchEntry) -> String {
        let trimmed = entry.opponentName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? lang.t("matches.unknown_opponent") : trimmed
    }

    /// Pill marking an unfinished, auto-saved entry. Tapping the row opens
    /// it for editing; the user can finish (Save) or delete it.
    private var draftBadge: some View {
        Text(lang.t("matches.draft_badge"))
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(AppPalette.clay)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(AppPalette.clay.opacity(0.14)))
    }

    /// Pill marking a planned, not-yet-played match.
    private var upcomingBadge: some View {
        Text(lang.t("matches.upcoming_badge"))
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(AppPalette.clay)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(AppPalette.clay.opacity(0.14)))
    }

    private func resultBadge(for result: MatchResult) -> some View {
        let label = result == .won ? "W" : "L"
        let color: Color = result == .won ? AppPalette.moss : AppPalette.alert
        return Text(label)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(Circle().fill(color))
    }

    private func surfaceColor(_ surface: MatchSurface) -> Color {
        switch surface {
        case .clay:  return AppPalette.CourtSurface.clay.base
        case .grass: return AppPalette.CourtSurface.grass.base
        case .hard:  return AppPalette.CourtSurface.hard.base
        }
    }

    private func dateDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppPalette.clay.opacity(0.10))
                    .frame(width: 96, height: 96)
                Image(systemName: "scribble.variable")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(AppPalette.clay)
            }
            .padding(.top, 30)

            Text(lang.t("matches.empty_title"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .multilineTextAlignment(.center)

            Text(lang.t("matches.empty_body"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.tap()
                openNewEntry = true
            } label: {
                Label(lang.t("matches.first_log_cta"), systemImage: "plus")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppPalette.clay)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
