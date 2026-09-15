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
    @EnvironmentObject private var session: UserSessionManager
    @State private var showLog = false
    @State private var rating: NutritionEntry?
    @State private var showPaywall = false
    /// Off by default. Sends a short summary (averages, comparisons, last
    /// five sessions) with each AI Coach message — never the raw log.
    @AppStorage("CourtIQ.Nutrition.ShareWithCoach") private var shareWithCoach = false
    #if DEBUG
    @State private var qcPush: String?
    #endif

    private var guide: NutritionGuide? { NutritionContentStore.guide(for: lang.language) }
    private var recipes: NutritionRecipeBook? { NutritionContentStore.recipes(for: lang.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                actionCard
                insightsCard
                contentCards
                if !manager.entries.isEmpty { coachShareCard }
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
            case "recipes", "guide", "today", "section", "recipe": qcPush = ProcessInfo.processInfo.environment["QC_NUTRITION"]
            default: break
            }
        }
        .navigationDestination(isPresented: Binding(get: { qcPush != nil }, set: { if !$0 { qcPush = nil } })) {
            switch qcPush {
            case "recipes": if let recipes { NutritionRecipesView(book: recipes) }
            case "guide":   if let guide { NutritionGuideView(guide: guide) }
            case "today":   if let guide { NutritionTodayView(guide: guide) }
            case "section": if let s = guide?.sections.first { NutritionGuideSectionView(section: s) }
            case "recipe":  if let r = recipes?.recipes.first { NutritionRecipeDetailView(recipe: r) }
            default: EmptyView()
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
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "Nutrition")
                    .environmentObject(session)
                    .environmentObject(lang)
            }
        }
    }

    // MARK: Guide · Today · Recipes

    /// The guide and the "today" picker are free; the recipe set is part of
    /// Premium. All three only appear when their content shipped in the
    /// bundle, so a language build without the JSON degrades to the log.
    @ViewBuilder
    private var contentCards: some View {
        if let guide {
            NavigationLink { NutritionTodayView(guide: guide) } label: {
                contentCard("questionmark.circle.fill", lang.t("nutrition.today_card_title"), lang.t("nutrition.today_card_sub"), locked: false)
            }
            .buttonStyle(PressableCardStyle())
            NavigationLink { NutritionGuideView(guide: guide) } label: {
                contentCard("book.closed.fill", lang.t("nutrition.guide_card_title"), lang.t("nutrition.guide_card_sub"), locked: false)
            }
            .buttonStyle(PressableCardStyle())
        }
        if let recipes {
            if session.isPremiumUnlocked {
                NavigationLink { NutritionRecipesView(book: recipes) } label: {
                    contentCard("fork.knife.circle.fill", lang.t("nutrition.recipes_card_title"), lang.t("nutrition.recipes_card_sub"), locked: false)
                }
                .buttonStyle(PressableCardStyle())
            } else {
                Button {
                    Haptics.tap()
                    showPaywall = true
                } label: {
                    contentCard("lock.fill", lang.t("nutrition.recipes_card_title"), lang.t("nutrition.recipes_card_locked"), locked: true)
                }
                .buttonStyle(PressableCardStyle())
            }
        }
    }

    /// Premium-only, off by default, explained on the card: what goes, what
    /// never goes. A free player sees the same card locked, so the switch is
    /// a reason to upgrade rather than a surprise after.
    private var coachShareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if session.isPremiumUnlocked {
                Toggle(isOn: $shareWithCoach) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(lang.t("nutrition.share_title"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppPalette.ink)
                        Text(lang.t("nutrition.share_body"))
                            .font(.footnote)
                            .foregroundStyle(AppPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(AppPalette.clay)
            } else {
                Button {
                    Haptics.tap()
                    showPaywall = true
                } label: {
                    contentCard("lock.fill", lang.t("nutrition.share_title"), lang.t("nutrition.share_locked"), locked: true)
                }
                .buttonStyle(PressableCardStyle())
            }
        }
        .padding(session.isPremiumUnlocked ? 14 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(session.isPremiumUnlocked ? AppPalette.parchment : .clear,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(session.isPremiumUnlocked ? AppPalette.sand : .clear, lineWidth: 1))
    }

    private func contentCard(_ symbol: String, _ title: String, _ sub: String, locked: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(locked ? AppPalette.goldText : AppPalette.clay)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                Text(sub)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft.opacity(0.7))
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(fill: locked ? AppPalette.goldTint.opacity(0.45) : AppPalette.parchment,
                     stroke: locked ? AppPalette.gold.opacity(0.4) : AppPalette.sand, cornerRadius: 16)
        .contentShape(Rectangle())
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
