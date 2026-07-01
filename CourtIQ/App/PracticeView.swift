// Superseded by TrainView (Phase 1 IA redesign)
import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                practiceHero

                VStack(alignment: .leading, spacing: 14) {
                    Text(lang.t("practice.skill_blocks"))
                        .font(.title3.bold())

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
                                practiceCard(for: category, isLocked: false)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                practiceCard(for: category, isLocked: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text(lang.t("practice.support_work"))
                        .font(.title3.bold())

                    NavigationLink {
                        MobilityLibraryView()
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "figure.walk")
                                .font(.title2)
                                .foregroundStyle(AppPalette.clay)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(lang.t("practice.mobility_library"))
                                    .font(.headline)
                                Text(lang.t("practice.mobility_desc"))
                                    .foregroundStyle(AppPalette.inkSoft)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(AppPalette.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(AppPalette.sand, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("tab.practice"))
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "Practice")
                    .environmentObject(session)
            }
        }
    }

    private var practiceHero: some View {
        // Same topLeading-anchored layout pattern as TodayView's hero:
        // the ZStack alignment is .topLeading so the content VStack
        // fills naturally; the court watermark places itself top-right
        // via its own maxWidth alignment frame.
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12) {
                Text(lang.t("practice.deliberate_reps"))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppPalette.inkSoft)

                Text(lang.t("practice.choose_pattern"))
                    .appFont(28, weight: .bold)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(lang.t("practice.free_desc"))
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)

            // Watermark anchored top-right via alignment frame so it
            // never pulls the content layout with it.
            CourtTopDown(surface: .clay, lineOpacity: 0.5)
                .opacity(0.18)
                .frame(width: 90, height: 160)
                .padding(.top, 8)
                .padding(.trailing, 8)
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func tennisGlyph(for category: QuizCategory) -> TennisGlyphKind {
        switch category {
        case .serve:      return .serve
        case .returnPlay: return .backhand
        case .rally:      return .forehand
        case .net:        return .volley
        case .mental:     return .target
        case .doubles:    return .volley
        }
    }

    private func practiceCard(for category: QuizCategory, isLocked: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                CourtLinesBg(color: .white.opacity(0.22))
                    .frame(width: 48, height: 48)
                TennisGlyph(kind: tennisGlyph(for: category), color: .white, size: 26)
            }
            .frame(width: 48, height: 48)
            .background(AppPalette.clay)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(category.title)
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                }
                Text(category.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
