import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager
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
                                QuizView(quiz: Quiz.practiceQuiz(category: category)) {
                                    session.updateCurrentFocus(category.title)
                                    session.updateTopMistakePatterns($0.mistakeTypes)
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
        ZStack(alignment: .topTrailing) {
            // Top-down clay court watermark
            CourtTopDown(surface: .clay, lineOpacity: 0.5)
                .opacity(0.18)
                .frame(width: 130, height: 200)
                .offset(x: 8, y: -10)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 12) {
                Text(lang.t("practice.deliberate_reps"))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppPalette.inkSoft)

                Text(lang.t("practice.choose_pattern"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(lang.t("practice.free_desc"))
                    .foregroundStyle(AppPalette.inkSoft)
            }
            .padding()
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
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                }
                Text(category.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
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
