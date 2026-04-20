import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var tipManager: TipManager
    @EnvironmentObject private var lang: LanguageManager

    @State private var tipExpanded = false

    private var dailyQuiz: Quiz { dailyQuizManager.todayQuiz }
    private var tip: DailyTip { tipManager.todayTip }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                tipCard
                dailyQuizCard
                mobilityCard
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("tab.today"))
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(greetingLine)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                streakPill(value: "\(dailyQuizManager.currentStreak)", label: lang.t("today.day_streak"))
                streakPill(value: "\(dailyQuizManager.completedThisWeek)/7", label: lang.t("today.this_week"))
            }

            NavigationLink {
                QuizView(quiz: dailyQuiz) { summary in
                    dailyQuizManager.recordCompletion(summary: summary, isDaily: true)
                    session.updateCurrentFocus(summary.focusLabel)
                    session.updateTopMistakePatterns(summary.mistakeTypes)
                }
            } label: {
                Text(dailyQuizManager.isCompletedToday ? lang.t("today.review_quiz") : lang.t("today.start_quiz"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white)
                    .foregroundStyle(AppPalette.clay)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(AppPalette.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var greetingLine: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        switch hour {
        case 5..<12: greeting = lang.t("today.greeting_morning")
        case 12..<17: greeting = lang.t("today.greeting_afternoon")
        default:     greeting = lang.t("today.greeting_evening")
        }
        if session.hasCompletedOnboarding {
            let focus = session.currentImprovementFocus
            return "\(greeting). \(lang.t("today.focus_label")) \(focus)."
        }
        return "\(greeting). \(lang.t("today.train_next"))"
    }

    private func streakPill(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Tip of the Day

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(tip.category.title, systemImage: tip.category.systemImage)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppPalette.clay.opacity(0.12))
                    .foregroundStyle(AppPalette.clay)
                    .clipShape(Capsule())
                Spacer()
                Text(lang.t("today.tip_of_day"))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }

            Text(tip.title)
                .font(.headline)

            if tipExpanded {
                Text(tip.body)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                if let source = tip.source {
                    Text("— \(source)")
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft.opacity(0.7))
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    tipExpanded.toggle()
                }
            } label: {
                Label(tipExpanded ? lang.t("today.show_less") : lang.t("today.read_more"),
                      systemImage: tipExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.clay)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Daily Quiz

    private var dailyQuizCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.t("today.daily_iq"))
                        .font(.headline)
                    Text(dailyQuizManager.isCompletedToday ? lang.t("today.completed") : lang.t("today.ready"))
                        .font(.caption)
                        .foregroundStyle(dailyQuizManager.isCompletedToday ? AppPalette.moss : AppPalette.inkSoft)
                }
                Spacer()
                infoChip(systemImage: "list.bullet", text: "\(dailyQuiz.questions.count) \(lang.t("today.questions"))")
            }

            Text(dailyQuiz.focusLabel)
                .font(.title3.bold())

            infoChip(systemImage: "target", text: dailyQuiz.primaryFocusTag ?? lang.t("today.match_awareness"))

            NavigationLink {
                QuizView(quiz: dailyQuiz) { summary in
                    dailyQuizManager.recordCompletion(summary: summary, isDaily: true)
                    session.updateCurrentFocus(summary.focusLabel)
                    session.updateTopMistakePatterns(summary.mistakeTypes)
                }
            } label: {
                Text(dailyQuizManager.isCompletedToday ? lang.t("today.review") : lang.t("today.start_quiz_btn"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Mobility

    @ViewBuilder
    private var mobilityCard: some View {
        // Safe lookup — show nothing if content hasn't loaded yet.
        let flows = MobilityFlow.sampleFlows
        if let flow = flows.first(where: { $0.type == .quickReset }) ?? flows.first {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(lang.t("today.quick_reset"))
                        .font(.headline)
                    Spacer()
                    if !session.isPremiumUnlocked {
                        premiumBadge
                    }
                }

                Text(flow.localizedTitle(for: lang.language))
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 8) {
                    infoChip(systemImage: "timer", text: flow.duration)
                    infoChip(systemImage: "figure.walk", text: flow.focusLabel)
                }

                NavigationLink {
                    MobilityFlowDetailView(flow: flow)
                } label: {
                    Text(session.isPremiumUnlocked ? lang.t("today.open_flow") : lang.t("today.preview_flow"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    // MARK: - Helpers

    private var premiumBadge: some View {
        Text(lang.t("common.premium"))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppPalette.clay.opacity(0.12))
            .foregroundStyle(AppPalette.clay)
            .clipShape(Capsule())
    }

    private func infoChip(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppPalette.sand.opacity(0.5))
            .clipShape(Capsule())
    }
}
