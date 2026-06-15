import SwiftUI

/// A single entry in Home's unified "Recent" rail — one tappable card that can
/// represent a swing analysis, a logged match, a doubles report, a daily drill,
/// or a completed quiz. Each store contributes its most recent few; the
/// aggregator merges + sorts them newest-first and caps the rail at 8.
///
/// MINIMAL TEXT philosophy: every card is an icon + ONE metric + ONE word + a
/// tiny relative time. No sentences. The metric shape is chosen per kind so the
/// number alone carries meaning (a ring for 0–100 scores, a colored pill for a
/// W/L result, short bold text for a quiz fraction).

// MARK: - Kind

enum ActivityKind {
    case swing, match, doubles, drill, quiz

    /// Small SF Symbol shown top-left on the card (clay, hierarchical).
    var symbol: String {
        switch self {
        case .swing:   return "video.fill"
        case .match:   return "list.clipboard.fill"
        case .doubles: return "person.2.fill"
        case .drill:   return "scope"
        case .quiz:    return "checklist"
        }
    }

    /// The duotone photo used as the card's branded background, chosen to match
    /// the activity: swing→a stroke shot, match→match, doubles→doubles,
    /// drill→ball, quiz→court.
    var photo: String {
        switch self {
        case .swing:   return "PhotoForehand"
        case .match:   return "PhotoMatch"
        case .doubles: return "PhotoDoubles"
        case .drill:   return "PhotoBall"
        case .quiz:    return "PhotoCourt"
        }
    }
}

// MARK: - Metric

/// The center read on a card. One value, one shape — never a sentence.
enum ActivityMetric {
    /// 0–100 → a small ScoreRing.
    case score(Int)
    /// Win / Loss → a tiny colored pill (semantic green / red).
    case result(MatchResult)
    /// e.g. 8/10 → short bold text (quiz).
    case fraction(Int, Int)
}

// MARK: - Route

/// Where a tap goes. `.none` renders the card as a plain (non-button) card —
/// used by drill + quiz which have no per-session detail reachable from Home.
enum ActivityRoute {
    case swing(SwingAnalysisRecord)
    case match(String)              // MatchEntry.id
    case doubles(DoublesReport)
    case none
}

// MARK: - Activity

struct RecentActivity: Identifiable {
    let id: String
    let date: Date
    let kind: ActivityKind
    /// One word (a stroke name, "Match", "Doubles", "Drill", or "Quiz").
    let label: String
    let metric: ActivityMetric
    let route: ActivityRoute
}

// MARK: - Aggregator

/// Pulls the most recent few activities from each store, merges them, sorts
/// newest-first, and returns the top 8. Resilient to any store being empty.
/// All store access is @MainActor (the singletons are @MainActor isolated).
@MainActor
enum RecentActivityFeed {
    static func build(
        swingStore: SwingAnalysisStore,
        matchManager: MatchEntryManager,
        doublesStore: DoublesStore,
        drillManager: CourtTapDrillManager,
        quizManager: DailyQuizManager
    ) -> [RecentActivity] {
        var items: [RecentActivity] = []

        // Swings — score → ring. Newest-first already; take a few.
        for record in swingStore.records.prefix(4) {
            guard let score = record.score else { continue }
            items.append(RecentActivity(
                id: "swing-\(record.id.uuidString)",
                date: record.date,
                kind: .swing,
                label: strokeLabel(record.stroke),
                metric: .score(score),
                route: .swing(record)
            ))
        }

        // Matches — only COMPLETED with a result → result pill.
        let completedMatches = matchManager.entries
            .filter { $0.status == .completed && $0.result != nil }
            .prefix(4)
        for entry in completedMatches {
            guard let result = entry.result else { continue }
            items.append(RecentActivity(
                id: "match-\(entry.id)",
                date: entry.date,
                kind: .match,
                label: "Match",
                metric: .result(result),
                route: .match(entry.id)
            ))
        }

        // Doubles — compatibility score → ring.
        let doublesReports = doublesStore.reports
            .sorted { $0.date > $1.date }
            .prefix(4)
        for report in doublesReports {
            guard let score = report.score else { continue }
            items.append(RecentActivity(
                id: "doubles-\(report.id.uuidString)",
                date: report.date,
                kind: .doubles,
                label: "Doubles",
                metric: .score(score),
                route: .doubles(report)
            ))
        }

        // Drills — raw zone score normalized to 0–100% → ring. Non-navigating.
        for session in drillManager.sessions.prefix(4) {
            guard session.maxScore > 0 else { continue }
            let pct = Int((Double(session.score) / Double(session.maxScore) * 100).rounded())
            items.append(RecentActivity(
                id: "drill-\(session.id)",
                date: session.date,
                kind: .drill,
                label: "Drill",
                metric: .score(pct),
                route: .none
            ))
        }

        // Quizzes — correct/total → fraction text. Non-navigating.
        for record in quizManager.sessionHistory.prefix(4) {
            items.append(RecentActivity(
                id: "quiz-\(record.id)",
                date: record.completedAt,
                kind: .quiz,
                label: "Quiz",
                metric: .fraction(record.score, record.totalQuestions),
                route: .none
            ))
        }

        return Array(items.sorted { $0.date > $1.date }.prefix(8))
    }

    /// One-word stroke label for a swing card. Falls back to a generic "Swing".
    private static func strokeLabel(_ stroke: SwingStroke?) -> String {
        switch stroke {
        case .forehand: return "Forehand"
        case .backhand: return "Backhand"
        case .serve:    return "Serve"
        case .volley:   return "Volley"
        case .session:  return "Session"
        case .footwork: return "Footwork"
        case .none:     return "Swing"
        }
    }
}

// MARK: - Relative time

/// Compact relative time for the card's top-right corner: "now", "3h", "2d",
/// "5w". Intentionally tiny — no "ago", no full words.
enum CompactRelativeTime {
    static func string(for date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        let minutes = Int(seconds / 60)
        if minutes < 1 { return "now" }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 7 { return "\(days)d" }
        let weeks = days / 7
        if weeks < 52 { return "\(weeks)w" }
        let years = days / 365
        return "\(years)y"
    }
}

// MARK: - Activity card

/// Uniform ~112-wide card. TOP: kind icon (clay) + tiny relative time.
/// CENTER: the metric. BOTTOM: the one-word label. Navigating routes wrap it in
/// a NavigationLink + PressableCardStyle; `.none` renders a plain card.
struct ActivityCard: View {
    let activity: RecentActivity

    var body: some View {
        switch activity.route {
        case .swing(let record):
            NavigationLink { SwingReportDetailView(record: record) } label: { cardBody }
                .buttonStyle(PressableCardStyle())
        case .match(let id):
            NavigationLink { matchDestination(id) } label: { cardBody }
                .buttonStyle(PressableCardStyle())
        case .doubles(let report):
            NavigationLink { DoublesReportDetailView(report: report) } label: { cardBody }
                .buttonStyle(PressableCardStyle())
        case .none:
            cardBody
        }
    }

    @ViewBuilder
    private func matchDestination(_ id: String) -> some View {
        MatchDetailView(entryID: id)
            .environmentObject(MatchEntryManager.shared)
            .environmentObject(LanguageManager.shared)
            .environmentObject(UserSessionManager.shared)
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: activity.kind.symbol)
                    .font(.subheadline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text(CompactRelativeTime.string(for: activity.date))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }

            HStack {
                Spacer(minLength: 0)
                metricView
                Spacer(minLength: 0)
            }

            Text(activity.label)
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(width: 112, alignment: .leading)
        .padding(14)
        // Fixed-width rail card: clamp very large sizes so the label + metric
        // stay inside the 112pt card instead of truncating hard.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        // Per-kind duotone photo + .bottom scrim; light foreground above keeps
        // text/icons legible. ScoreRing flips to white over the scrim.
        .brandedPhoto(activity.kind.photo, scrim: .bottom, cornerRadius: 20)
    }

    @ViewBuilder
    private var metricView: some View {
        switch activity.metric {
        case .score(let value):
            ScoreRing(size: 34, score: value, accent: .white,
                      track: .white.opacity(0.3))
        case .result(let result):
            resultPill(result)
        case .fraction(let correct, let total):
            Text("\(correct)/\(total)")
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
                .monospacedDigit()
                .frame(height: 34)
        }
    }

    private func resultPill(_ result: MatchResult) -> some View {
        let isWin = result == .won
        return Text(isWin ? "W" : "L")
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(Circle().fill(isWin ? AppPalette.moss : AppPalette.alert))
    }
}
