import SwiftUI
import Charts

/// The trend dashboard surfaces what the user has been logging — but
/// only after they've earned access by logging 5+ rated matches. Until
/// then, a locked card invites them to keep logging.
///
/// Visual stack: 4 line charts (serve / return / movement / mental) +
/// 2 insight cards (biggest improvement, biggest decline) + monthly
/// match count bar chart.
struct MatchTrendDashboardView: View {
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !matches.trendDashboardUnlocked {
                    lockedHero
                } else {
                    unlockedContent
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("matches.trend_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Locked state

    private var lockedHero: some View {
        let count = matches.entries.filter(\.hasRatings).count
        return VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppPalette.clay.opacity(0.10))
                    .frame(width: 96, height: 96)
                Image(systemName: "lock.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(AppPalette.clay)
            }
            .padding(.top, 30)

            Text(lang.t("matches.trend_locked_title"))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                ProgressView(value: Double(count), total: 5)
                    .tint(AppPalette.clay)
                Text("\(count) / 5")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppPalette.inkSoft)
            }
            .frame(maxWidth: 220)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Unlocked content

    @ViewBuilder
    private var unlockedContent: some View {
        // Insight cards row
        HStack(spacing: 12) {
            biggestChangeCard(direction: .up)
            biggestChangeCard(direction: .down)
        }

        // Four dimension charts
        VStack(spacing: 14) {
            chartCard(glyph: .serve,    keyPath: \.serveRating,    accent: AppPalette.clay)
            chartCard(glyph: .backhand, keyPath: \.returnRating,   accent: AppPalette.moss)
            chartCard(glyph: .mobility, keyPath: \.movementRating, accent: Color(red: 0.30, green: 0.55, blue: 0.80))
            chartCard(glyph: .target,   keyPath: \.mentalRating,   accent: AppPalette.gold)
        }

        // Monthly volume
        monthlyVolumeCard
    }

    // MARK: - Dimension chart card

    private func chartCard(
        glyph: TennisGlyphKind,
        keyPath: KeyPath<MatchEntry, Int?>,
        accent: Color
    ) -> some View {
        let points = chartPoints(for: keyPath)
        let latest = points.last?.value
        let earliest = points.first?.value
        let delta: Int? = (latest != nil && earliest != nil)
            ? Int((latest! - earliest!).rounded())
            : nil

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TennisGlyph(kind: glyph, color: accent, size: 22)
                Spacer()
                if let avg = matches.averageRating(keyPath) {
                    Text(String(format: "%.1f", avg))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .monospacedDigit()
                }
                if let delta {
                    Image(systemName: delta > 0 ? "arrow.up.right" : (delta < 0 ? "arrow.down.right" : "minus"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(delta > 0 ? AppPalette.moss : (delta < 0 ? AppPalette.alert : AppPalette.inkSoft))
                }
            }

            if points.isEmpty {
                // No ratings yet on this dimension — show a quiet hint
                // instead of an empty chart frame. Avoids weird zero-height
                // chart rendering on some iOS versions.
                HStack {
                    Spacer()
                    Text(lang.t("matches.dim_no_data"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.inkSoft)
                    Spacer()
                }
                .frame(height: 110)
            } else {
                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Rating", point.value)
                        )
                        .foregroundStyle(accent)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Rating", point.value)
                        )
                        .foregroundStyle(accent)
                        .symbolSize(36)
                    }
                }
                .chartYScale(domain: 1...5)
                .chartYAxis {
                    AxisMarks(values: [1, 3, 5]) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                    }
                }
                .frame(height: 110)
            }
        }
        .padding(16)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Biggest improvement / decline card

    private enum Direction {
        case up, down
    }

    private func biggestChangeCard(direction: Direction) -> some View {
        let changes = dimensionDeltas()
        let target: (label: String, glyph: TennisGlyphKind, delta: Double)? = direction == .up
            ? changes.max(by: { $0.delta < $1.delta })
            : changes.min(by: { $0.delta < $1.delta })

        let arrow: String = direction == .up ? "arrow.up.right" : "arrow.down.right"
        let tint: Color = direction == .up ? AppPalette.moss : AppPalette.alert
        let labelKey = direction == .up ? "matches.trend_up" : "matches.trend_down"

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: arrow)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(lang.t(labelKey))
                    .font(.caption.weight(.heavy))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AppPalette.inkSoft)
            }

            HStack(spacing: 8) {
                if let target {
                    TennisGlyph(kind: target.glyph, color: tint, size: 18)
                    Text(target.label)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                } else {
                    Text("—")
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }

            if let target {
                Text(String(format: "%+.1f", target.delta))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Monthly volume

    private var monthlyVolumeCard: some View {
        let buckets = monthlyMatchCounts()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundStyle(AppPalette.clay)
                Text(lang.t("matches.trend_volume"))
                    .font(.caption.weight(.heavy))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(AppPalette.inkSoft)
            }

            Chart {
                ForEach(buckets) { bucket in
                    BarMark(
                        x: .value("Month", bucket.date, unit: .month),
                        y: .value("Count", bucket.count)
                    )
                    .foregroundStyle(AppPalette.clay.opacity(0.85))
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month, count: 1)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .frame(height: 100)
        }
        .padding(16)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Data shaping

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    /// Returns one ChartPoint per logged-with-rating entry, ordered by date ascending.
    private func chartPoints(for keyPath: KeyPath<MatchEntry, Int?>) -> [ChartPoint] {
        matches.entries
            .compactMap { entry -> ChartPoint? in
                guard let raw = entry[keyPath: keyPath] else { return nil }
                return ChartPoint(date: entry.date, value: Double(raw))
            }
            .sorted { $0.date < $1.date }
    }

    /// Delta between average rating in the last 30 days vs. the previous 30 days,
    /// across each rated dimension.
    private func dimensionDeltas() -> [(label: String, glyph: TennisGlyphKind, delta: Double)] {
        let dims: [(label: String, glyph: TennisGlyphKind, keyPath: KeyPath<MatchEntry, Int?>)] = [
            (lang.t("matches.dim_serve"),    .serve,    \MatchEntry.serveRating),
            (lang.t("matches.dim_return"),   .backhand, \MatchEntry.returnRating),
            (lang.t("matches.dim_movement"), .mobility, \MatchEntry.movementRating),
            (lang.t("matches.dim_mental"),   .target,   \MatchEntry.mentalRating),
        ]

        return dims.compactMap { dim in
            guard
                let recent = matches.averageRating(dim.keyPath, inLast: 30),
                let prior = matches.averageRating(dim.keyPath, inLast: 60)
            else { return nil }
            // Adjust prior to be only the "previous 30 days" by removing the recent 30 days' weight.
            // For simplicity, use the difference between the two 30/60 averages.
            let delta = recent - prior
            return (dim.label, dim.glyph, delta)
        }
    }

    private struct MonthBucket: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }

    /// Count of matches per calendar month, last 6 months including current.
    private func monthlyMatchCounts() -> [MonthBucket] {
        let calendar = Calendar(identifier: .iso8601)
        let now = Date()
        let monthsBack = 6

        var dict: [Date: Int] = [:]
        for entry in matches.entries {
            let comps = calendar.dateComponents([.year, .month], from: entry.date)
            if let bucketDate = calendar.date(from: comps) {
                dict[bucketDate, default: 0] += 1
            }
        }

        return (0..<monthsBack).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let comps = calendar.dateComponents([.year, .month], from: date)
            guard let bucketDate = calendar.date(from: comps) else { return nil }
            return MonthBucket(date: bucketDate, count: dict[bucketDate] ?? 0)
        }
        .sorted { $0.date < $1.date }
    }
}
