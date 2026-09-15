import SwiftUI

/// Nutrition, slice 1: the fuel log. Log the last meal before playing, rate
/// the session after, and let the player's own averages say what works.
/// Everything stays on the device.
///
/// The screen has one job at a time, so the action card shows exactly one
/// button: "Rate how you felt" when a session is waiting on its rating,
/// otherwise "Log before you play".
struct NutritionView: View {
    @ObservedObject private var manager = NutritionManager.shared
    @EnvironmentObject private var lang: LanguageManager
    @State private var showLog = false
    @State private var rating: NutritionEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                actionCard
                insightsCard
                if !manager.entries.isEmpty { recent }
                Text(lang.t("nutrition.disclaimer"))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("nutrition.title"))
        .navigationBarTitleDisplayMode(.inline)
        #if DEBUG
        // Headless QC: SIMCTL_CHILD_QC_NUTRITION=log|rate opens a sheet on appear.
        .onAppear {
            switch ProcessInfo.processInfo.environment["QC_NUTRITION"] {
            case "log":  showLog = true
            case "rate": rating = manager.entries.first
            default: break
            }
        }
        #endif
        .sheet(isPresented: $showLog) {
            NutritionLogSheet()
                .environmentObject(lang)
        }
        .sheet(item: $rating) { entry in
            NutritionRateSheet(entry: entry)
                .environmentObject(lang)
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(lang.t("nutrition.eyebrow"))
            Text(lang.t("nutrition.headline"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(lang.t("nutrition.intro"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var actionCard: some View {
        if let pending = manager.pendingRating {
            VStack(alignment: .leading, spacing: 10) {
                Text(lang.t("nutrition.rate_hint"))
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                PrimaryButton(title: lang.t("nutrition.rate_cta"), icon: "hand.thumbsup") {
                    rating = pending
                }
            }
            .padding(16)
            .cardSurface(fill: AppPalette.goldTint.opacity(0.55), stroke: AppPalette.gold.opacity(0.4), cornerRadius: 18)
        } else {
            PrimaryButton(title: lang.t("nutrition.log_cta"), icon: "fork.knife") {
                showLog = true
            }
        }
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(lang.t("nutrition.insights"))
            let rated = manager.ratedEntries
            if let avg = NutritionInsights.averages(rated) {
                averagesRow(avg)
            }
            let insights = manager.insights
            if insights.isEmpty {
                Text(String(format: lang.t("nutrition.empty_insights_fmt"),
                            NutritionInsights.sessionsUntilFirstInsight(rated),
                            NutritionInsights.minimumSessions))
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(insights) { insight in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundStyle(AppPalette.moss)
                            .frame(width: 22)
                        Text(String(format: lang.t("nutrition.insight_fmt"),
                                    lang.t(insight.dimension.labelKey),
                                    lang.t(insight.betterLabelKey), insight.betterMean, insight.betterCount,
                                    lang.t(insight.worseLabelKey), insight.worseMean, insight.worseCount))
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 18)
    }

    private func averagesRow(_ avg: NutritionAverages) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: lang.t("nutrition.averages_fmt"), avg.count))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)
            HStack(spacing: 8) {
                averagePill(lang.t("nutrition.rate_energy"), avg.energy)
                averagePill(lang.t("nutrition.rate_legs"), avg.legs)
                averagePill(lang.t("nutrition.rate_focus"), avg.focus)
                averagePill(lang.t("nutrition.rate_stomach"), avg.stomach)
            }
        }
    }

    private func averagePill(_ label: String, _ value: Double) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%.1f", value))
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(AppPalette.ink)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppPalette.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppPalette.cream, in: RoundedRectangle(cornerRadius: 12))
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(lang.t("nutrition.recent"))
            ForEach(manager.entries.prefix(10)) { entry in
                entryRow(entry)
            }
        }
    }

    private func entryRow(_ entry: NutritionEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.kind.symbol)
                .foregroundStyle(AppPalette.clay)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.date, style: .date)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Text([lang.t(entry.timing.labelKey),
                      entry.meal.map { lang.t($0.labelKey) },
                      lang.t(entry.hydration.labelKey),
                      entry.caffeine ? lang.t("nutrition.caffeine_yes") : nil]
                        .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                if let note = entry.note, !note.isEmpty {
                    Text("“\(note)”")
                        .font(.caption.italic())
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }
            Spacer(minLength: 6)
            if let r = entry.ratings {
                Text(String(format: "%.1f", r.composite))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(AppPalette.mossDeep)
                    .monospacedDigit()
            } else {
                Button {
                    Haptics.tap()
                    rating = entry
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
        .contextMenu {
            Button(role: .destructive) { manager.delete(entry.id) } label: {
                Label(lang.t("nutrition.delete"), systemImage: "trash")
            }
        }
    }
}
