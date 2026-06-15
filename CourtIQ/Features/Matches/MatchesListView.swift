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
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One-shot flag so the tutorial auto-presents only on the first visit
    /// to the Matches tab. Re-openable any time via the (i) button.
    @AppStorage("CourtIQ.matchLogTutorialSeen.v1") private var tutorialSeen = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                streakHeader
                    .reveal(appeared: appeared, index: 0, reduceMotion: reduceMotion)
                if matches.entries.isEmpty {
                    emptyState
                        .reveal(appeared: appeared, index: 1, reduceMotion: reduceMotion)
                } else {
                    insightShortcuts
                        .reveal(appeared: appeared, index: 1, reduceMotion: reduceMotion)
                    MatchCalendarView()
                        .environmentObject(matches)
                        .environmentObject(lang)
                        .reveal(appeared: appeared, index: 2, reduceMotion: reduceMotion)
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
            withAnimation(Motion.entrance) { appeared = true }
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
                Eyebrow(lang.t("matches.total_logged"))
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
                    .foregroundStyle(.white)
                    .frame(width: 28)
                Text(lang.t("matches.view_insights"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(14)
            // Duotone court photo + .bottom scrim; light foreground keeps the
            // shortcut legible (it's a navigation card, not a chart).
            .brandedPhoto("PhotoCourt", scrim: .bottom, cornerRadius: 16)
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: - Entry list

    private var entryList: some View {
        VStack(spacing: 10) {
            ForEach(Array(matches.entries.enumerated()), id: \.element.id) { index, entry in
                NavigationLink {
                    MatchDetailView(entryID: entry.id)
                        .environmentObject(matches)
                        .environmentObject(lang)
                        .environmentObject(session)
                } label: {
                    entryRow(entry)
                }
                .buttonStyle(PressableCardStyle())
                .reveal(appeared: appeared, index: 3 + index, reduceMotion: reduceMotion)
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
                        .foregroundStyle(.white)
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
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()

            if entry.aiReport != nil || entry.aiPreComment != nil {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(14)
        // Duotone match photo + .bottom scrim; row text/icons flip to white so
        // the opponent + date + badges stay legible over the photo.
        .brandedPhoto("PhotoMatch", scrim: .bottom, cornerRadius: 18)
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
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(.white.opacity(0.22)))
    }

    /// Pill marking a planned, not-yet-played match.
    private var upcomingBadge: some View {
        Text(lang.t("matches.upcoming_badge"))
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(.white.opacity(0.22)))
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
                    .fill(.white.opacity(0.16))
                    .frame(width: 96, height: 96)
                Image(systemName: "scribble.variable")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.top, 30)

            Text(lang.t("matches.empty_title"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(lang.t("matches.empty_body"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.tap()
                openNewEntry = true
            } label: {
                Label(lang.t("matches.first_log_cta"), systemImage: "plus")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.clay)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        // Empty-state hero on a duotone match photo with a strong .hero scrim;
        // all foreground flips to white (CTA inverts to white-on-clay) so the
        // first-log nudge clears contrast over the photo.
        .brandedPhoto("PhotoMatch", scrim: .hero, cornerRadius: 24)
    }
}

// MARK: - Staggered entrance modifier

private extension View {
    /// Tactile entrance: opacity + a small rise + slight scale, staggered by
    /// index with a bouncy spring. A no-op (instant) under Reduce Motion.
    /// Mirrors the Home/Train reveal so Matches shares one motion language.
    @ViewBuilder
    func reveal(appeared: Bool, index: Int, reduceMotion: Bool) -> some View {
        if reduceMotion {
            self.opacity(appeared ? 1 : 0)
        } else {
            self
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .scaleEffect(appeared ? 1 : 0.96)
                .animation(Motion.entrance.delay(Double(index) * Motion.stagger),
                           value: appeared)
        }
    }
}
