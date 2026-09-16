import SwiftUI
import Charts

/// The Daily Tennis IQ loop: one-time baseline placement → 5-scenario daily
/// session → mastery summary with the IQ delta. Reuses the drop-in `QuizView`
/// for every question flow; all scoring lives in `TennisIQManager` /
/// `TennisIQEngine` (deterministic, explainable — no invented numbers).
struct DailyIQView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var tabRouter: TabRouter
    @ObservedObject private var iq = TennisIQManager.shared
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable { case intro, placement, placementResult, session, summary }
    @State private var phase: Phase = .intro
    @State private var iqBefore = 0
    @State private var xpBefore = 0
    @State private var lastScore = 0
    @State private var lastTotal = 0
    #if DEBUG
    /// QC-only session override (see the QC_IQ_PHASE hook below).
    @State private var qcQuiz: Quiz?
    #endif

    // NOT debug-only, despite having been written inside the block above once:
    // `tacticsBridge` is a shipping feature for players without Premium, and
    // with these three behind `#if DEBUG` the file did not compile in Release
    // at all. Keep them out here.
    /// The Tactics course, read-only, so the summary can offer the lessons that
    /// TEACH what these scenarios just tested — and say how many are left.
    @State private var tacticsContent = ContentStore()
    @State private var tacticsProgress = PlayerProgress()
    @State private var showTacticsPaywall = false

    private var sessionQuiz: Quiz {
        #if DEBUG
        if let qcQuiz { return qcQuiz }
        #endif
        return iq.todaySession()
    }

    var body: some View {
        Group {
            switch phase {
            case .intro:
                intro
            case .placement:
                QuizView(quiz: iq.placementQuiz(), title: lang.t("iq.placement_title")) { summary in
                    iq.recordPlacement(results: summary.perQuestionResults ?? [:])
                    phase = .placementResult
                }
            case .placementResult:
                placementResult
            case .session:
                QuizView(quiz: sessionQuiz, title: lang.t("iq.daily_title")) { summary in
                    lastScore = summary.score
                    lastTotal = summary.totalQuestions
                    iq.recordSession(results: summary.perQuestionResults ?? [:])
                    // Same manager that powers Profile stats + the unified streak.
                    dailyQuizManager.recordCompletion(summary: summary, isDaily: true)
                    session.updateTopMistakePatterns(summary.mistakeTypes)
                    phase = .summary
                }
            case .summary:
                summaryView
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phase)
        #if DEBUG
        // Headless QC: SIMCTL_CHILD_QC_IQ_PHASE=summary|placementResult jumps
        // straight to a phase so screens are screenshot-testable without taps.
        .onAppear {
            switch ProcessInfo.processInfo.environment["QC_IQ_PHASE"] {
            case "summary":
                iqBefore = iq.iq; xpBefore = iq.xpTotal   // honest delta in QC too
                lastScore = 4; lastTotal = 5
                phase = .summary
            case "placementResult":
                phase = .placementResult
            case "session":
                // Optional QC_IQ_CAT=doubles etc. pins the session to a
                // category's first unit (deterministic screenshots).
                if let raw = ProcessInfo.processInfo.environment["QC_IQ_CAT"],
                   let category = QuizCategory(rawValue: raw),
                   let unit = iq.units(for: category).first {
                    qcQuiz = iq.practiceQuiz(for: unit)
                }
                phase = .session
            default:
                break
            }
        }
        #endif
    }

    // MARK: - Intro (score header + baseline offer or daily CTA)

    private var intro: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                scoreHeader

                if !iq.hasBaseline {
                    actionCard(
                        title: lang.t("iq.baseline_title"),
                        body: lang.t("iq.baseline_body"),
                        primary: lang.t("iq.baseline_start"),
                        primaryAction: { startPlacement() },
                        secondary: lang.t("iq.baseline_skip"),
                        secondaryAction: {
                            iq.skipPlacement()
                            startSession()
                        }
                    )
                } else if iq.completedSessionToday {
                    actionCard(
                        title: lang.t("iq.done_title"),
                        body: lang.t("iq.done_body"),
                        primary: lang.t("iq.train_more"),
                        primaryAction: { startSession() }
                    )
                } else {
                    actionCard(
                        title: lang.t("iq.daily_ready_title"),
                        body: lang.t("iq.daily_ready_body"),
                        primary: lang.t("iq.daily_start"),
                        primaryAction: { startSession() }
                    )
                }

                categoryBars

                if iq.iqHistory.count >= 2 {
                    iqChart
                }
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("iq.daily_title"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showTacticsPaywall) { TacticsPaywallSheet() }
        .onAppear { tacticsProgress = PlayerProgress() }
    }

    /// IQ over time — only appears once there are 2+ points, so a brand-new
    /// user never sees an empty chart.
    private var iqChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(lang.t("iq.chart_title"))
            Chart(iq.iqHistory.suffix(14), id: \.dayKey) { point in
                LineMark(x: .value("Day", point.dayKey), y: .value("IQ", point.iq))
                    .foregroundStyle(AppPalette.clay)
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Day", point.dayKey), y: .value("IQ", point.iq))
                    .foregroundStyle(AppPalette.clay)
            }
            .chartYScale(domain: 60...160)
            .chartXAxis(.hidden)
            .frame(height: 120)
        }
        .padding(16)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
    }

    private var scoreHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(lang.t("iq.eyebrow"))
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(iq.iq)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                    .contentTransition(.numericText())
                Text(String(format: lang.t("iq.of_max_fmt"), TennisIQEngine.ceiling))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
                if ActivityManager.shared.currentStreak > 0 {
                    Label("\(ActivityManager.shared.currentStreak)", systemImage: "flame.fill")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppPalette.clay)
                }
            }
            Text(String(format: lang.t("iq.mastered_fmt"), iq.masteredCount, iq.totalCount))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(String(format: lang.t("iq.scale_note"),
                        TennisIQEngine.floor, TennisIQEngine.ceiling,
                        TennisIQEngine.placementPoints, iq.totalCount))
                .font(.footnote)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if iq.isBaselineEstimated && iq.hasBaseline {
                Text(lang.t("iq.estimated_chip"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(AppPalette.sand, in: Capsule())
                    .foregroundStyle(AppPalette.ink)
            }
        }
    }

    /// HIG audit B5: ONE list carries the whole map — mastery bar + count +
    /// navigation into the category's units. (Was two lists of the same six
    /// categories: "court map" bars + "skill path" links.)
    private var categoryBars: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(lang.t("iq.categories"))
            ForEach(QuizCategory.allCases, id: \.self) { category in
                let value = iq.categoryMastery[category] ?? 0
                let units = iq.units(for: category)
                let mastered = units.reduce(0) { $0 + iq.masteredCount(in: $1) }
                let total = units.reduce(0) { $0 + $1.questionIDs.count }
                NavigationLink {
                    IQCategoryUnitsView(category: category)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: category.systemImage)
                            .font(.footnote)
                            .frame(width: 22)
                            .foregroundStyle(AppPalette.clay)
                        Text(lang.t(category.localizationKey))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppPalette.ink)
                            .frame(width: 82, alignment: .leading)
                            .lineLimit(1)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppPalette.sand.opacity(0.6))
                                Capsule().fill(AppPalette.clay)
                                    .frame(width: max(6, geo.size.width * value))
                            }
                        }
                        .frame(height: 8)
                        if category == iq.weakestCategory {
                            Text(lang.t("iq.focus_chip"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppPalette.gold)
                        }
                        Text("\(mastered)/\(total)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(lang.t(category.localizationKey)): \(mastered)/\(total)")
            }
        }
        .padding(16)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: - Placement result

    private var placementResult: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(lang.t("iq.baseline_set"))
                    Text("\(iq.iq)")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                    Text(lang.t("iq.eyebrow"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                if let blindSpot = iq.placementBlindSpot {
                    HStack(spacing: 10) {
                        Image(systemName: blindSpot.systemImage)
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(lang.t("iq.blind_spot"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white.opacity(0.85))
                            Text(blindSpot.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(AppPalette.ink, in: RoundedRectangle(cornerRadius: 16))
                }

                actionCard(
                    title: lang.t("iq.daily_ready_title"),
                    body: lang.t("iq.daily_ready_body"),
                    primary: lang.t("iq.daily_start"),
                    primaryAction: { startSession() },
                    secondary: lang.t("iq.done_button"),
                    secondaryAction: { dismiss() }
                )
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("iq.placement_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Session summary (the Duolingo moment)

    private var summaryView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(lang.t("iq.summary_title"))
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("\(iq.iq)")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundStyle(AppPalette.ink)
                            .contentTransition(.numericText())
                        Text(String(format: lang.t("iq.of_max_fmt"), TennisIQEngine.ceiling))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.secondary)
                        if iq.iq > iqBefore {
                            Text("+\(iq.iq - iqBefore)")
                                .font(.system(.title2, design: .rounded).weight(.black))
                                .foregroundStyle(AppPalette.gold)
                        }
                    }
                    Text(lang.t("iq.eyebrow"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    statChip(String(format: lang.t("iq.summary_correct_fmt"), lastScore, lastTotal),
                             systemImage: "checkmark.circle.fill")
                    statChip(String(format: lang.t("iq.xp_fmt"), max(0, iq.xpTotal - xpBefore)),
                             systemImage: "bolt.fill")
                    if ActivityManager.shared.currentStreak > 0 {
                        statChip(String(format: lang.t("iq.streak_fmt"), ActivityManager.shared.currentStreak),
                                 systemImage: "flame.fill")
                    }
                }

                Text(String(format: lang.t("iq.mastered_fmt"), iq.masteredCount, iq.totalCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                tacticsBridge

                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Text(lang.t("iq.done_button"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppPalette.clay, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(PressableCardStyle())
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("iq.daily_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Bridge from scenarios to the lessons that teach them

    /// A scenario session tests a decision; the Tactics course is where that
    /// decision is taught. Shown to players who are not premium, and it leads
    /// where they actually are: into the free chapter if they have not started
    /// it, to the membership once their free lesson for today is spent.
    @ViewBuilder
    private var tacticsBridge: some View {
        if !PremiumGate.isPremium(session) {
            let started = tacticsProgress.completedCount > 0
            let spent = started && !tacticsProgress.hasFreeDailyLesson
            Button {
                Haptics.tap()
                if spent { showTacticsPaywall = true } else { tabRouter.selection = .tactics; dismiss() }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow(lang.t("iq.bridge_eyebrow"))
                    Text(lang.t("iq.bridge_title"))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(String(format: lang.t("iq.bridge_body"),
                                tacticsContent.totalLessonCount, tacticsContent.chapters.count))
                        .font(.footnote)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(spent ? lang.t("iq.bridge_cta_unlock") : lang.t("iq.bridge_cta_open"))
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(.footnote, design: .rounded).weight(.bold))
                    .foregroundStyle(AppPalette.clayText)
                    .padding(.top, 2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.parchment)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressableCardStyle())
        }
    }

    // MARK: - Pieces

    private func startPlacement() {
        Haptics.tap()
        iqBefore = iq.iq
        xpBefore = iq.xpTotal
        phase = .placement
    }

    private func startSession() {
        Haptics.tap()
        iqBefore = iq.iq
        xpBefore = iq.xpTotal
        phase = .session
    }

    private func statChip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote.weight(.bold))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.white.opacity(0.7), in: Capsule())
            .foregroundStyle(AppPalette.ink)
    }

    private func actionCard(title: String, body: String,
                            primary: String, primaryAction: @escaping () -> Void,
                            secondary: String? = nil, secondaryAction: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppPalette.ink)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                primaryAction()
            } label: {
                Text(primary)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppPalette.clay, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableCardStyle())
            if let secondary, let secondaryAction {
                Button {
                    secondaryAction()
                } label: {
                    Text(secondary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.clay)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Skill path: units of one category

/// One category's rungs (easy→hard). Unit 1 is open; each next unit unlocks
/// once the previous one has been fully attempted.
struct IQCategoryUnitsView: View {
    let category: QuizCategory

    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var lang: LanguageManager
    @ObservedObject private var iq = TennisIQManager.shared
    @State private var activeUnit: TennisIQUnit?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(iq.units(for: category)) { unit in
                    let unlocked = iq.isUnitUnlocked(unit)
                    let mastered = iq.masteredCount(in: unit)
                    Button {
                        guard unlocked else { return }
                        Haptics.tap()
                        activeUnit = unit
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .stroke(AppPalette.sand, lineWidth: 5)
                                Circle()
                                    .trim(from: 0, to: CGFloat(mastered) / CGFloat(max(1, unit.questionIDs.count)))
                                    .stroke(AppPalette.clay, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text("\(unit.index)")
                                    .font(.system(.subheadline, design: .rounded).weight(.black))
                                    .foregroundStyle(AppPalette.ink)
                            }
                            .frame(width: 40, height: 40)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(String(format: lang.t("iq.unit_fmt"), unit.index))
                                    .font(.headline)
                                    .foregroundStyle(unlocked ? AppPalette.ink : .secondary)
                                Text("\(mastered)/\(unit.questionIDs.count)")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: unlocked ? "chevron.right" : "lock.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(.white.opacity(unlocked ? 0.7 : 0.35), in: RoundedRectangle(cornerRadius: 18))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        "\(String(format: lang.t("iq.unit_fmt"), unit.index)), \(mastered)/\(unit.questionIDs.count)"
                        + (unlocked ? "" : ", \(lang.t("iq.locked"))")
                    )
                }
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t(category.localizationKey))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $activeUnit) { unit in
            QuizView(quiz: iq.practiceQuiz(for: unit)) { summary in
                iq.recordPractice(results: summary.perQuestionResults ?? [:])
                // History + Profile stats; not the daily ritual.
                dailyQuizManager.recordCompletion(summary: summary, isDaily: false)
            }
        }
    }
}
