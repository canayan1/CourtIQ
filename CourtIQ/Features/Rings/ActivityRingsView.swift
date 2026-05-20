import SwiftUI

/// Apple Activity Rings, tennis edition.
///
/// Three concentric arcs:
/// - **Outer (clay)** — Quiz Ring, closed when the user completes the
///   Daily Court Tap Drill.
/// - **Middle (moss)** — Match Ring, closed when the user logs any
///   match entry today (Journal or Quick Log).
/// - **Inner (gold)** — Mobility Ring, closed when the user starts any
///   mobility flow today.
///
/// Closing all three is a "Triple Ring Day" — celebrated with haptics
/// and counted toward the year-end recap (future feature).
struct ActivityRingsView: View {
    let quizProgress: Double
    let matchProgress: Double
    let mobilityProgress: Double

    /// Size of the outer ring. Inner rings shrink proportionally.
    var size: CGFloat = 160

    private var lineWidth: CGFloat { size * 0.10 }
    private var ringSpacing: CGFloat { lineWidth + 4 }

    private let quizColor = AppPalette.clay
    private let matchColor = AppPalette.moss
    private let mobilityColor = AppPalette.gold

    var body: some View {
        ZStack {
            ring(progress: quizProgress, color: quizColor, ringSize: size)
            ring(progress: matchProgress, color: matchColor,
                 ringSize: size - ringSpacing * 2)
            ring(progress: mobilityProgress, color: mobilityColor,
                 ringSize: size - ringSpacing * 4)
        }
        .frame(width: size, height: size)
    }

    private func ring(progress: Double, color: Color, ringSize: CGFloat) -> some View {
        let clamped = max(0, min(1, progress))
        return ZStack {
            // Track
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)

            // Progress arc — when 100% closed, render a thicker complete
            // circle with a subtle highlight so closed rings stand out.
            if clamped >= 1.0 {
                Circle()
                    .stroke(color, lineWidth: lineWidth)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.0), color.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: lineWidth * 0.5
                    )
            } else {
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
        }
        .frame(width: ringSize, height: ringSize)
        .animation(.easeInOut(duration: 0.35), value: clamped)
    }
}

/// Compact three-ring card used on Today and Profile. Shows the rings +
/// a legend with the three ring labels and their current daily state.
struct ThreeRingsCard: View {
    @EnvironmentObject private var drillManager: CourtTapDrillManager
    @EnvironmentObject private var matchManager: MatchEntryManager
    @EnvironmentObject private var lang: LanguageManager

    @State private var celebratedKey: String?

    private var quizProgress: Double { drillManager.completedToday ? 1 : 0 }
    private var matchProgress: Double { matchManager.loggedToday ? 1 : 0 }
    private var mobilityProgress: Double {
        MobilityFlowSessionTracker.shared.startedToday ? 1 : 0
    }

    private var allThreeClosed: Bool {
        quizProgress >= 1 && matchProgress >= 1 && mobilityProgress >= 1
    }

    private var todayKey: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    var body: some View {
        HStack(spacing: 18) {
            ActivityRingsView(
                quizProgress: quizProgress,
                matchProgress: matchProgress,
                mobilityProgress: mobilityProgress,
                size: 120
            )

            VStack(alignment: .leading, spacing: 12) {
                ringRow(color: AppPalette.clay,
                        glyph: .target,
                        text: lang.t("rings.quiz"),
                        done: quizProgress >= 1)
                ringRow(color: AppPalette.moss,
                        glyph: .racket,
                        text: lang.t("rings.match"),
                        done: matchProgress >= 1)
                ringRow(color: AppPalette.gold,
                        glyph: .mobility,
                        text: lang.t("rings.mobility"),
                        done: mobilityProgress >= 1)
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
        .onChange(of: allThreeClosed) { _, closed in
            // Celebrate exactly once per day when the user closes all three.
            guard closed, celebratedKey != todayKey else { return }
            celebratedKey = todayKey
            Haptics.celebrate()
            TripleRingTracker.shared.recordTripleRing(for: Date())
        }
    }

    private func ringRow(color: Color, glyph: TennisGlyphKind, text: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle()
                        .stroke(color, lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                )
            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(done ? AppPalette.ink : AppPalette.inkSoft)
            Spacer(minLength: 0)
            if done {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(color)
            }
        }
    }
}

/// Tracks how many days the user has hit a Triple Ring. The actual
/// year-end recap reads from this.
@MainActor
final class TripleRingTracker {
    static let shared = TripleRingTracker()
    private let defaults = UserDefaults.standard
    private let key = "CourtIQ.tripleRingDates.v1"

    private(set) var dates: Set<String>

    private init() {
        if let array = defaults.array(forKey: key) as? [String] {
            self.dates = Set(array)
        } else {
            self.dates = []
        }
    }

    func recordTripleRing(for date: Date) {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        let key = f.string(from: date)
        dates.insert(key)
        defaults.set(Array(dates), forKey: self.key)
    }

    var count: Int { dates.count }
}

/// Tiny tracker for "started a mobility flow today" — the mobility tab
/// already exists; this just records the date on tap. The Mobility flow
/// detail view will call `recordStarted()` once we wire it up.
@MainActor
final class MobilityFlowSessionTracker: ObservableObject {
    static let shared = MobilityFlowSessionTracker()
    private let defaults = UserDefaults.standard
    private let key = "CourtIQ.mobilitySessionDates.v1"

    @Published private(set) var startedDates: Set<String>

    private init() {
        if let array = defaults.array(forKey: key) as? [String] {
            self.startedDates = Set(array)
        } else {
            self.startedDates = []
        }
    }

    func recordStarted(date: Date = Date()) {
        startedDates.insert(Self.dayKey(for: date))
        defaults.set(Array(startedDates), forKey: key)
    }

    var startedToday: Bool {
        startedDates.contains(Self.dayKey(for: Date()))
    }

    private static func dayKey(for date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
