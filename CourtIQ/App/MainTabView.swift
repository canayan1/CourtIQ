import SwiftUI

/// Routes tab selection so the Home tiles can SWITCH tabs (Matches / Coach /
/// Doubles) rather than push a duplicate of those screens inside the Home
/// NavigationStack.
final class TabRouter: ObservableObject {
    enum Tab: Hashable { case home, train, matches, doubles, coach }
    @Published var selection: Tab = .home
}

struct MainTabView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @StateObject private var tabRouter = TabRouter()
    @State private var showActivation = false

    // 5 tabs only — iOS pushes a 6th into a "More" overflow that buries it.
    // Phase 1 IA redesign + action-first Home:
    //   1. Home    — action-first landing (flagship swing hero + 2×2 grid).
    //                Profile ("Me") lives behind the avatar button in the
    //                Home header, NOT a tab.
    //   2. Train   — the improve hub.
    //   3. Matches — the post-pivot centerpiece.
    //   4. Doubles — the doubles compatibility surface.
    //   5. Coach   — the AI Coach.
    var body: some View {
        TabView(selection: $tabRouter.selection) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label(lang.t("tab.home"), systemImage: "house.fill")
            }
            .tag(TabRouter.Tab.home)

            NavigationStack {
                TrainView()
            }
            .tabItem {
                Label(lang.t("tab.train"), systemImage: "figure.strengthtraining.traditional")
            }
            .tag(TabRouter.Tab.train)

            NavigationStack {
                MatchesListView()
            }
            .tabItem {
                Label(lang.t("tab.matches"), systemImage: "pencil.and.list.clipboard")
            }
            .tag(TabRouter.Tab.matches)

            NavigationStack {
                DoublesView()
            }
            .tabItem {
                Label(lang.t("tab.doubles"), systemImage: "person.2.fill")
            }
            .tag(TabRouter.Tab.doubles)

            NavigationStack {
                AICoachTabRoot()
            }
            .tabItem {
                Label(lang.t("tab.coach"), systemImage: "sparkles")
            }
            .tag(TabRouter.Tab.coach)
        }
        .tint(AppPalette.clay)
        .environmentObject(tabRouter)
        .id(lang.language)
        .fullScreenCover(isPresented: $showActivation) {
            ActivationView(
                onAskCoach: {
                    session.markActivationSeen()
                    showActivation = false
                    tabRouter.selection = .coach
                },
                onFinish: {
                    session.markActivationSeen()
                    showActivation = false
                }
            )
            .environmentObject(lang)
        }
        .task {
            // First launch after onboarding: prove the app is smart in ~15s.
            // `-previewActivation` forces it for testing regardless of state.
            if ProcessInfo.processInfo.arguments.contains("-previewActivation")
                || (session.hasCompletedOnboarding && !session.hasSeenActivation) {
                showActivation = true
            }
        }
    }
}

// MARK: - First-run activation (2-step: IQ taste → Coach nudge)

/// Shown once, as a full-screen cover the first time `MainTabView` appears
/// after onboarding. Step 1 poses a single Tennis-IQ scenario with an instant
/// "why" (the moat, proven free in seconds); step 2 nudges toward the AI Coach
/// flagship. Both exits call `markActivationSeen()` so it never repeats.
private struct ActivationView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Finish + jump to the Coach tab.
    let onAskCoach: () -> Void
    /// Finish, stay where they are.
    let onFinish: () -> Void

    @State private var step: Int
    @State private var selected: Int?
    @State private var revealed = false

    private let question: QuizQuestion?

    init(onAskCoach: @escaping () -> Void, onFinish: @escaping () -> Void) {
        self.onAskCoach = onAskCoach
        self.onFinish = onFinish
        let q = Quiz.dailyQuiz().questions.first
        self.question = q
        _step = State(initialValue: q == nil ? 1 : 0)   // empty bank → skip to Coach
    }

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    Group {
                        if step == 0, let question {
                            iqTaste(question)
                        } else {
                            coachNudge
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? AppPalette.clay : AppPalette.clay.opacity(0.22))
                        .frame(width: i == step ? 22 : 8, height: 6)
                        .animation(reduceMotion ? nil : Motion.reveal, value: step)
                }
            }
            Spacer()
            Button(lang.t("activation.skip")) { onFinish() }
                .appFont(15, weight: .semibold)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    // MARK: Step 1 — one IQ scenario with an instant "why"
    @ViewBuilder
    private func iqTaste(_ q: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Eyebrow(lang.t("activation.iq_eyebrow"))
            Text(q.localizedScenario(for: lang.language))
                .appFont(22, weight: .bold)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(Array(q.localizedOptions(for: lang.language).enumerated()), id: \.offset) { idx, option in
                    optionRow(idx: idx, option: option, correct: q.correctAnswerIndex)
                }
            }

            if revealed {
                VStack(alignment: .leading, spacing: 10) {
                    Label(selected == q.correctAnswerIndex ? lang.t("activation.correct") : lang.t("activation.incorrect"),
                          systemImage: selected == q.correctAnswerIndex ? "checkmark.circle.fill" : "lightbulb.fill")
                        .appFont(17, weight: .bold)
                        .foregroundStyle(AppPalette.clay)
                    Text(q.localizedExplanation(for: lang.language))
                        .appFont(15)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppPalette.parchment, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .transition(.opacity)

                primaryButton(lang.t("activation.continue"), icon: nil) {
                    withAnimation(reduceMotion ? nil : Motion.reveal) { step = 1 }
                }
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    private func optionRow(idx: Int, option: String, correct: Int) -> some View {
        let isChosen = selected == idx
        let isCorrect = idx == correct
        let bg: Color = !revealed ? AppPalette.parchment
            : isCorrect ? AppPalette.clay.opacity(0.16)
            : isChosen ? Color.red.opacity(0.10)
            : AppPalette.parchment
        let border: Color = !revealed ? .clear
            : isCorrect ? AppPalette.clay
            : isChosen ? Color.red.opacity(0.45)
            : .clear
        return Button {
            guard !revealed else { return }
            Haptics.tap()
            selected = idx
            withAnimation(reduceMotion ? nil : Motion.reveal) { revealed = true }
        } label: {
            HStack(spacing: 12) {
                Text(option)
                    .appFont(15, weight: .semibold)
                    .foregroundStyle(AppPalette.ink)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if revealed && isCorrect {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(AppPalette.clay)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        .disabled(revealed)
    }

    // MARK: Step 2 — Coach nudge
    private var coachNudge: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow(lang.t("activation.coach_eyebrow"))
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .appFont(44, weight: .bold)
                .foregroundStyle(AppPalette.clay)
            Text(lang.t("activation.coach_title"))
                .appFont(26, weight: .heavy)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(lang.t("activation.coach_body"))
                .appFont(16)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            primaryButton(lang.t("activation.coach_cta"), icon: "sparkles") { onAskCoach() }
                .padding(.top, 6)

            Button(lang.t("activation.later")) { onFinish() }
                .appFont(15, weight: .semibold)
                .foregroundStyle(AppPalette.inkSoft)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 24)
        .padding(.bottom, 32)
    }

    private func primaryButton(_ title: String, icon: String?, _ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .appFont(17, weight: .bold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppPalette.clay, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(PressableCardStyle())
    }
}
