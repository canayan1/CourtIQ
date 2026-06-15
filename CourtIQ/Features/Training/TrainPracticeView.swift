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
                                             title: category.title,
                                             photo: category.photo)
                            }
                            .buttonStyle(PressableCardStyle())
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                LockableTile(sfSymbol: category.systemImage,
                                             title: category.title,
                                             locked: true,
                                             photo: category.photo)
                            }
                            .buttonStyle(PressableCardStyle())
                        }
                    }
                }

                Button {
                    showDrill = true
                } label: {
                    iconRow(systemImage: "scope",
                            title: lang.t("train.drill_label"),
                            photo: "PhotoFootwork")
                }
                .buttonStyle(PressableCardStyle())

                if proShotManager.todaysPattern != nil {
                    Button {
                        showProShot = true
                    } label: {
                        iconRow(systemImage: "trophy.fill",
                                title: lang.t("train.pro_shot_label"),
                                photo: "PhotoGear")
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

    /// Full-width action row. When `photo` is set it renders a duotone
    /// `BrandedPhotoBackground` (.bottom scrim) with a LIGHT foreground; when
    /// nil it keeps the original parchment fill + sand stroke.
    private func iconRow(systemImage: String, title: String, photo: String? = nil) -> some View {
        let foreground: Color = photo == nil ? AppPalette.ink : .white
        let iconTint: Color = photo == nil ? AppPalette.clay : .white
        return HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(iconTint)
                .frame(width: 28)

            Text(title)
                .font(.headline)
                .foregroundStyle(foreground)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(photo == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.white.opacity(0.85)))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(IconRowBackground(photo: photo))
    }
}

/// Background recipe for `TrainPracticeView.iconRow`: parchment+stroke when
/// `photo` is nil, duotone branded photo (.bottom scrim) when set. Mirrors the
/// shared tile pattern but keeps the row's 22pt corner radius.
private struct IconRowBackground: ViewModifier {
    let photo: String?
    func body(content: Content) -> some View {
        if let photo {
            content.brandedPhoto(photo, scrim: .bottom, cornerRadius: 22)
        } else {
            content
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}
