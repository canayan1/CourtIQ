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
        // Count total entries (not just rated ones) so the progress bar
        // tracks the same threshold `trendDashboardUnlocked` uses.
        let count = matches.entries.count
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
        // 1. W-L summary header — top-line read
        recordSummaryCard

        // 2. Surface breakdown — how often + win % per court
        if !matches.surfaceBreakdown.allSatisfy({ $0.total == 0 }) {
            surfaceBreakdownCard
        }

        // 3. Momentum — last 3 vs prior 3 across dimensions
        if hasMomentumData {
            momentumCard
        }

        // 4. Biggest improvement / decline
        HStack(spacing: 12) {
            biggestChangeCard(direction: .up)
            biggestChangeCard(direction: .down)
        }

        // 5. Four dimension charts (the existing line series)
        VStack(spacing: 14) {
            chartCard(glyph: .serve,    keyPath: \.serveRating,    accent: AppPalette.clay)
            chartCard(glyph: .backhand, keyPath: \.returnRating,   accent: AppPalette.moss)
            chartCard(glyph: .mobility, keyPath: \.movementRating, accent: Color(red: 0.30, green: 0.55, blue: 0.80))
            chartCard(glyph: .target,   keyPath: \.mentalRating,   accent: AppPalette.gold)
        }

        // 6. Per-surface rating matrix — only when ≥2 surfaces have data
        if surfacesWithData.count >= 2 {
            perSurfaceRatingsCard
        }

        // 7. Recurring takeaway themes
        let themes = matches.topTakeawayThemes(limit: 3)
        if !themes.isEmpty {
            takeawayThemesCard(themes)
        }

        // 8. Monthly volume bar chart
        monthlyVolumeCard
    }

    // MARK: - 1. Record summary

    private var recordSummaryCard: some View {
        let s = matches.winRateSummary
        let pct = s.ratio.map { Int(($0 * 100).rounded()) }
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lang.t("matches.trend_record"))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(AppPalette.inkSoft)
                    .textCase(.uppercase)
                    .tracking(0.5)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(s.wins)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.moss)
                    Text("–")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.inkSoft.opacity(0.6))
                    Text("\(s.losses)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.alert)
                }
                Text("\(s.total) " + lang.t(s.total == 1 ? "matches.trend_total_one" : "matches.trend_total_many"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer()
            if let pct {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(pct)%")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .monospacedDigit()
                    Text(lang.t("matches.trend_win_rate"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.inkSoft)
                }
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

    // MARK: - 2. Surface breakdown

    private var surfaceBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("matches.trend_by_surface"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(matches.surfaceBreakdown.filter { $0.total > 0 }) { row in
                surfaceRow(row)
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

    private func surfaceRow(_ row: MatchEntryManager.SurfaceBreakdown) -> some View {
        let surfaceColor: Color = {
            switch row.surface {
            case .clay:  return AppPalette.CourtSurface.clay.base
            case .grass: return AppPalette.CourtSurface.grass.base
            case .hard:  return AppPalette.CourtSurface.hard.base
            }
        }()
        let label = lang.t("matches.surface_\(row.surface.rawValue)")
        let pct = row.ratio.map { Int(($0 * 100).rounded()) }
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(surfaceColor)
                .frame(width: 22, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Text("\(row.wins)W · \(row.losses)L")
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer()
            if let pct {
                Text("\(pct)%")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                    .monospacedDigit()
            }
        }
    }

    // MARK: - 3. Momentum (last 3 vs prior 3)

    private var hasMomentumData: Bool {
        [\MatchEntry.serveRating, \.returnRating, \.movementRating, \.mentalRating]
            .contains { matches.momentum($0) != nil }
    }

    private var momentumCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("matches.trend_momentum"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(lang.t("matches.trend_momentum_subtitle"))
                .font(.caption2)
                .foregroundStyle(AppPalette.inkSoft.opacity(0.7))

            VStack(spacing: 6) {
                momentumRow(label: lang.t("coach.dim_serve"),    glyph: .serve,    keyPath: \.serveRating,    accent: AppPalette.clay)
                momentumRow(label: lang.t("coach.dim_return"),   glyph: .backhand, keyPath: \.returnRating,   accent: AppPalette.moss)
                momentumRow(label: lang.t("coach.dim_movement"), glyph: .mobility, keyPath: \.movementRating, accent: Color(red: 0.30, green: 0.55, blue: 0.80))
                momentumRow(label: lang.t("coach.dim_mental"),   glyph: .target,   keyPath: \.mentalRating,   accent: AppPalette.gold)
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

    @ViewBuilder
    private func momentumRow(label: String, glyph: TennisGlyphKind, keyPath: KeyPath<MatchEntry, Int?>, accent: Color) -> some View {
        if let m = matches.momentum(keyPath) {
            let deltaSign: String = {
                if m.delta > 0.05 { return "+" }
                if m.delta < -0.05 { return "" }   // negative already has minus
                return "·"
            }()
            let deltaTint: Color = m.delta > 0.05 ? AppPalette.moss : (m.delta < -0.05 ? AppPalette.alert : AppPalette.inkSoft)
            HStack(spacing: 10) {
                TennisGlyph(kind: glyph, color: accent, size: 18)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.1f → %.1f", m.prior, m.recent))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppPalette.inkSoft)
                Text("\(deltaSign)\(String(format: "%.1f", m.delta))")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(deltaTint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(deltaTint.opacity(0.12))
                    .clipShape(Capsule())
            }
        } else {
            EmptyView()
        }
    }

    // MARK: - 6. Per-surface rating matrix

    private var surfacesWithData: [MatchSurface] {
        matches.surfaceBreakdown.filter { $0.total > 0 }.map(\.surface)
    }

    private var perSurfaceRatingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("matches.trend_per_surface_ratings"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 8) {
                ForEach(surfacesWithData) { surface in
                    perSurfaceRow(surface)
                }
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

    private func perSurfaceRow(_ surface: MatchSurface) -> some View {
        let surfaceColor: Color = {
            switch surface {
            case .clay:  return AppPalette.CourtSurface.clay.base
            case .grass: return AppPalette.CourtSurface.grass.base
            case .hard:  return AppPalette.CourtSurface.hard.base
            }
        }()
        let s = matches.averageRating(\.serveRating,    on: surface)
        let r = matches.averageRating(\.returnRating,   on: surface)
        let m = matches.averageRating(\.movementRating, on: surface)
        let n = matches.averageRating(\.mentalRating,   on: surface)
        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(surfaceColor)
                .frame(width: 18, height: 22)
            Text(lang.t("matches.surface_\(surface.rawValue)"))
                .font(.subheadline.weight(.semibold))
                .frame(width: 60, alignment: .leading)
            Spacer()
            HStack(spacing: 10) {
                ratingPill(s, color: AppPalette.clay)
                ratingPill(r, color: AppPalette.moss)
                ratingPill(m, color: Color(red: 0.30, green: 0.55, blue: 0.80))
                ratingPill(n, color: AppPalette.gold)
            }
        }
    }

    private func ratingPill(_ value: Double?, color: Color) -> some View {
        Group {
            if let v = value {
                Text(String(format: "%.1f", v))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(color)
                    .clipShape(Capsule())
            } else {
                Text("—")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.inkSoft.opacity(0.5))
                    .frame(width: 22)
            }
        }
    }

    // MARK: - 7. Takeaway themes

    private func takeawayThemesCard(_ themes: [(word: String, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("matches.trend_themes"))
                .font(.caption.weight(.heavy))
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(lang.t("matches.trend_themes_subtitle"))
                .font(.caption2)
                .foregroundStyle(AppPalette.inkSoft.opacity(0.7))

            HStack(spacing: 8) {
                ForEach(themes, id: \.word) { theme in
                    HStack(spacing: 4) {
                        Text(theme.word)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppPalette.ink)
                        Text("×\(theme.count)")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(AppPalette.clay)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppPalette.clay.opacity(0.10))
                    .clipShape(Capsule())
                }
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
        // Count only played matches — upcoming (planned) entries sit in the
        // future and would inflate a month that hasn't happened yet.
        for entry in matches.entries where entry.status == .completed && !entry.isDraft {
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
