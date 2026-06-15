import SwiftUI

/// The "improve" hub (Phase 1 IA redesign). Merges the old Practice + Training
/// tabs and absorbs the improvement tools that used to live on Today
/// (Swing Analysis, daily Court-Tap drill, Pro shot). It RE-HOMES existing
/// destination views — it does not reimplement any of them.
struct TrainView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var drillManager: CourtTapDrillManager
    @EnvironmentObject private var trainingProgress: TrainingProgressManager
    @EnvironmentObject private var proShotManager: ProShotPatternsManager

    private let programs = TrainingProgram.allPrograms

    @State private var showPaywall = false
    @State private var showDrill = false
    @State private var showProShot = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero

                analyzeSection
                practiceSection
                recoverSection
                programsSection
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("tab.train"))
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

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 12) {
                Text(lang.t("train.subtitle"))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppPalette.inkSoft)

                Text(lang.t("train.headline"))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)

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

    // MARK: - Analyze

    private var analyzeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(lang.t("train.analyze"))

            NavigationLink {
                SwingAnalysisView()
            } label: {
                iconRow(
                    systemImage: "video.fill",
                    iconTint: AppPalette.clay,
                    title: lang.t("train.analyze_title"),
                    subtitle: lang.t("train.analyze_desc")
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("trainSwingAnalysisCard")
        }
    }

    // MARK: - Practice

    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(lang.t("train.practice"))

            // The 5 quiz category cards — ported verbatim from PracticeView.
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

            // Daily drill — launches the Court Tap drill full-screen, same as
            // TodayView's drill card does.
            Button {
                showDrill = true
            } label: {
                iconRow(
                    systemImage: "scope",
                    iconTint: AppPalette.clay,
                    title: lang.t("train.daily_drill_title"),
                    subtitle: lang.t("train.daily_drill_desc")
                )
            }
            .buttonStyle(.plain)

            // Pro shot — launches the Pro Shot animation full-screen, same as
            // ProShotCard does. Hidden if no pattern is available.
            if proShotManager.todaysPattern != nil {
                Button {
                    showProShot = true
                } label: {
                    iconRow(
                        systemImage: "trophy.fill",
                        iconTint: AppPalette.gold,
                        title: lang.t("train.pro_shot_title"),
                        subtitle: lang.t("train.pro_shot_desc")
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Recover

    private var recoverSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(lang.t("train.recover"))

            NavigationLink {
                MobilityLibraryView()
            } label: {
                iconRow(
                    systemImage: "figure.walk",
                    iconTint: AppPalette.clay,
                    title: lang.t("practice.mobility_library"),
                    subtitle: lang.t("practice.mobility_desc")
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Programs (ported from TrainingHubView)

    private var programsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(lang.t("train.programs"))

            featuredCard
            premiumTracks
        }
    }

    private var featuredCard: some View {
        let program = TrainingProgram.featuredProgram

        return ZStack(alignment: .topTrailing) {
            TennisRacket(color: .white.opacity(0.16), accent: .white.opacity(0.35), angle: -22)
                .frame(width: 130, height: 182)
                .offset(x: 28, y: -8)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                programSectionHeader(title: lang.t("training.free_foundation"),
                                     subtitle: lang.t("training.start_here"))

                Text(program.title)
                    .font(.title3.bold())

                VStack(alignment: .leading, spacing: 6) {
                    Text("8-Week Training Block")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(.white)
                    Text("Plyometrics, hypertrophy, explosiveness, conditioning")
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.white.opacity(0.88))
                }

                HStack(spacing: 4) {
                    ForEach(1...8, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(.white.opacity(i <= 2 ? 0.85 : 0.28))
                            .frame(height: 6)
                    }
                }

                Text("Repeat the weekly structure for 8 weeks, log each session, and compare your persistence checks over time.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))

                NavigationLink {
                    TrainingProgramDetailView(program: program)
                } label: {
                    Text(lang.t("training.open_plan"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .background(AppPalette.trainingGradient)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var premiumTracks: some View {
        VStack(alignment: .leading, spacing: 14) {
            programSectionHeader(title: lang.t("training.premium_tracks"),
                                 subtitle: session.isPremiumUnlocked ? lang.t("training.unlocked") : lang.t("training.locked"))

            ForEach(programs.filter(\.isPremium)) { program in
                NavigationLink {
                    TrainingProgramDetailView(program: program)
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: program.category.symbolName)
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(session.isPremiumUnlocked ? AppPalette.moss : AppPalette.inkSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(program.title)
                                    .font(.headline)
                                if !session.isPremiumUnlocked {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(AppPalette.inkSoft)
                                }
                            }

                            Text(program.category.summary)
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.inkSoft)

                            Text(program.emphasis.joined(separator: " • "))
                                .font(.caption)
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
    }

    // MARK: - Building blocks

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
    }

    private func programSectionHeader(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer()
        }
    }

    /// Generic parchment card with a leading SF Symbol, title + subtitle, and a
    /// trailing chevron — the standard list-card look used across the app.
    private func iconRow(systemImage: String, iconTint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(iconTint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppPalette.ink)
                Text(subtitle)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Practice quiz card (ported from PracticeView)

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
