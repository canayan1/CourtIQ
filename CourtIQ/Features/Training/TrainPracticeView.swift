import SwiftUI

/// Practice level of the Train tree: the 5 quiz categories as a 2-column grid
/// plus a Drill row and (when available) a Pro shot row. Premium gating and the
/// quiz-record closure are preserved verbatim from the old TrainView hub.
struct TrainPracticeView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var drillManager: CourtTapDrillManager
    @EnvironmentObject private var proShotManager: ProShotPatternsManager

    @State private var showPaywall = false
    @State private var showDrill = false
    @State private var showProShot = false

    private let columns = [GridItem(.flexible(), spacing: 12),
                           GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(QuizCategory.allCases) { category in
                        if session.isPremiumUnlocked {
                            NavigationLink {
                                QuizView(quiz: Quiz.practiceQuiz(category: category)) { summary in
                                    // Record into the same manager that powers
                                    // Profile stats (totalQuizzesCompleted /
                                    // weekly history). isDaily: false keeps the
                                    // "completed today" daily-ritual flag intact.
                                    dailyQuizManager.recordCompletion(summary: summary, isDaily: false)
                                    session.updateCurrentFocus(category.title)
                                    session.updateTopMistakePatterns(summary.mistakeTypes)
                                }
                            } label: {
                                LockableTile(sfSymbol: category.systemImage,
                                             title: category.title)
                            }
                            .buttonStyle(PressableCardStyle())
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                LockableTile(sfSymbol: category.systemImage,
                                             title: category.title,
                                             locked: true)
                            }
                            .buttonStyle(PressableCardStyle())
                        }
                    }
                }

                Button {
                    showDrill = true
                } label: {
                    iconRow(systemImage: "scope",
                            title: lang.t("train.drill_label"))
                }
                .buttonStyle(PressableCardStyle())

                if proShotManager.todaysPattern != nil {
                    Button {
                        showProShot = true
                    } label: {
                        iconRow(systemImage: "trophy.fill",
                                title: lang.t("train.pro_shot_label"))
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("train.practice"))
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "Practice")
                    .environmentObject(session)
                    .environmentObject(lang)
            }
        }
        .fullScreenCover(isPresented: $showDrill) {
            NavigationStack {
                CourtTapDrillView()
                    .environmentObject(lang)
                    .environmentObject(drillManager)
            }
        }
        .fullScreenCover(isPresented: $showProShot) {
            if let pattern = proShotManager.todaysPattern {
                ProShotAnimationView(pattern: pattern)
                    .environmentObject(lang)
            }
        }
    }

    // MARK: - Tiles

    private func iconRow(systemImage: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(AppPalette.clay)
                .frame(width: 28)

            Text(title)
                .font(.headline)
                .foregroundStyle(AppPalette.ink)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
