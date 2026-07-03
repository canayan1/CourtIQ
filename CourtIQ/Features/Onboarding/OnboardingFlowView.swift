import SwiftUI
import StoreKit

/// Lightweight, single-tap onboarding for the freemium model. Four quick
/// questions (goal, experience, level, pain points) build the Tennis Profile;
/// a labor-illusion "building" beat and a personalized reveal follow, then the
/// user is IN the app — no paywall handoff, no long interrogation.
///
/// Everything the old 16-step flow asked explicitly (stroke ratings, pressure
/// response, wants, frequency…) is now INFERRED from these four answers with
/// neutral defaults — the in-app Tennis Profile questionnaire remains the
/// place to refine it later. Visual language mirrors
/// `TennisProfileQuestionnaireView`: cream background, parchment cards with a
/// sand stroke, clay-accented selection, one question per screen, nothing
/// pre-selected, Continue disabled until answered.
struct OnboardingFlowView: View {
    @EnvironmentObject private var lang: LanguageManager

    /// Called when onboarding finishes (after the review ask). The app roots
    /// straight into the main tabs — freemium, no paywall gate.
    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    private var copy: OnboardingCopy { OnboardingCopy(lang: lang.language) }
    private var tpCopy: TennisProfileCopy { TennisProfileCopy(lang: lang.language) }

    // MARK: Ordered steps

    private enum Step: Int, CaseIterable {
        case hook           // 0  positioning hook (full-bleed PhotoHero)
        case showcase       // 1  feature showcase (animated demos)
        case goal           // 2  framing goal — single tap
        case experience     // 3  TennisExperience — single tap
        case level          // 4  LevelSelfPlacement — single tap
        case weaknesses     // 5  pain points (fast multi-select)
        case building       // 6  labor illusion
        case result         // 7  personalized reveal
        case review         // 8  leave-a-review ask (peak enthusiasm) → done
    }

    /// Steps that show the top progress bar + Back/Continue chrome.
    private var questionSteps: [Step] {
        [.goal, .experience, .level, .weaknesses]
    }

    @State private var step: Step = .hook

    // MARK: Answer state — nothing pre-selected

    @State private var goal: OnboardingGoal?
    @State private var experience: TennisExperience?
    @State private var levelSelf: LevelSelfPlacement?
    @State private var weaknesses: Set<OnboardingWeakness> = []

    @State private var builtProfile: TennisProfile?

    var body: some View {
        Group {
            switch step {
            case .hook:
                OnboardingHookView { advance() }
            case .showcase:
                OnboardingShowcaseView { advance() }
            case .building:
                OnboardingBuildingView(stepLabels: buildingStepLabels) {
                    advance()
                }
            case .result:
                if let profile = builtProfile {
                    OnboardingResultView(
                        profile: profile,
                        goal: goal ?? .winMatches,
                        topWeaknessLabel: topWeaknessLabel
                    ) {
                        advance()
                    }
                }
            case .review:
                reviewScreen
            default:
                questionScaffold
            }
        }
        .background(AppPalette.cream)
        .animation(.easeInOut, value: step)
    }

    // MARK: Question scaffold (progress bar + content + Back/Continue)

    private var questionScaffold: some View {
        VStack(spacing: 0) {
            progressBar
                .padding(.horizontal, 20)
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    questionContent
                }
                .padding(20)
            }

            navigationButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .background(AppPalette.cream)
    }

    private var progressBar: some View {
        let total = questionSteps.count
        let done = questionSteps.firstIndex(of: step).map { $0 + 1 } ?? 0
        return HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i < done ? AppPalette.clay : AppPalette.sand)
                    .frame(height: 5)
            }
        }
    }

    @ViewBuilder
    private var questionContent: some View {
        switch step {
        case .goal:        goalStep
        case .experience:  experienceStep
        case .level:       levelStep
        case .weaknesses:  weaknessesStep
        default:           EmptyView()
        }
    }

    // MARK: 2 — Goal

    private var goalStep: some View {
        questionBlock(copy.goalQuestion) {
            ForEach(OnboardingGoal.allCases) { g in
                optionRow(copy.goalOption(g), isSelected: goal == g) { goal = g }
            }
        }
    }

    // MARK: 3 — Experience

    private var experienceStep: some View {
        questionBlock(tpCopy.qExperience) {
            ForEach(TennisExperience.allCases, id: \.self) { v in
                optionRow(tpCopy.experienceOption(v), isSelected: experience == v) { experience = v }
            }
        }
    }

    // MARK: 4 — Level self-placement (+ provisional note)

    private var levelStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            questionBlock(tpCopy.qLevel) {
                ForEach(LevelSelfPlacement.allCases, id: \.self) { v in
                    optionRow(tpCopy.levelOption(v), isSelected: levelSelf == v) { levelSelf = v }
                }
            }
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .appFont(14, design: .default)
                    .foregroundStyle(AppPalette.clay)
                    .padding(.top, 1)
                Text(tpCopy.provisionalNote)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.clay.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    // MARK: 5 — Weaknesses (multi-select pain points)

    private var weaknessesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(copy.weaknessQuestion)
                .font(.title3.bold())
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(copy.weaknessHint)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
            VStack(spacing: 10) {
                ForEach(OnboardingWeakness.allCases) { w in
                    multiSelectRow(copy.weaknessOption(w), isSelected: weaknesses.contains(w)) {
                        if weaknesses.contains(w) { weaknesses.remove(w) } else { weaknesses.insert(w) }
                    }
                }
            }
        }
    }

    // MARK: 8 — Leave a review (peak enthusiasm, right after the reveal)

    private var reviewScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            // Five stars filling one by one — priming OUR review ask (this is
            // a rating request, not a claim about existing ratings).
            AnimatedStarsRow()

            Text(copy.reviewTitle)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(copy.reviewBody)
                .font(.body)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    requestReview()
                    Haptics.tap()
                    onComplete()
                } label: {
                    Text(copy.reviewRate)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)

                Button {
                    Haptics.tap()
                    onComplete()
                } label: {
                    Text(copy.reviewLater)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(AppPalette.inkSoft)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppPalette.cream)
    }

    /// Triggers the native App Store review prompt in the active window scene.
    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    // MARK: Reusable pieces

    private func questionBlock<Content: View>(
        _ title: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 10) {
                content()
            }
        }
    }

    private func optionRow(_ title: String, isSelected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .appFont(20, design: .default)
                    .foregroundStyle(isSelected ? AppPalette.clay : AppPalette.sand)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppPalette.clay : AppPalette.sand, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
    }

    private func multiSelectRow(_ title: String, isSelected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .appFont(20, design: .default)
                    .foregroundStyle(isSelected ? AppPalette.clay : AppPalette.sand)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? AppPalette.clay : AppPalette.sand, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableCardStyle())
    }

    // MARK: Navigation chrome (question steps only)

    private var navigationButtons: some View {
        VStack(spacing: 10) {
            Button {
                advance()
            } label: {
                Text(copy.next)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
            .disabled(!currentStepComplete)

            Button {
                goBack()
            } label: {
                Text(copy.back)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(AppPalette.inkSoft)
        }
        .padding(.top, 6)
    }

    // MARK: Completion logic (Continue gating)

    private var currentStepComplete: Bool {
        switch step {
        case .hook, .showcase, .building, .result, .review:
            return true
        case .goal:        return goal != nil
        case .experience:  return experience != nil
        case .level:       return levelSelf != nil
        case .weaknesses:  return !weaknesses.isEmpty
        }
    }

    // MARK: Step transitions

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        Haptics.tap()
        // Build + save the profile exactly when we leave the last question
        // (weaknesses) and enter the building screen.
        if step == .weaknesses {
            buildAndSaveProfile()
        }
        withAnimation { step = next }
    }

    private func goBack() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation { step = prev }
    }

    // MARK: Inference (fewer questions, same engine)

    /// The 4 quick answers stand in for the old 10-question interrogation.
    /// Removed inputs are INFERRED with conservative defaults so the Tennis
    /// Profile engine still gets a full answer set; the in-app questionnaire
    /// remains the place to refine them later.

    /// Stroke self-ratings: neutral 3 everywhere, 2 on dimensions the user
    /// explicitly named as pain points — so the picked weaknesses genuinely
    /// shape the level/archetype result without a 6×5 rating matrix.
    private var inferredRatings: [TennisDimension: Int] {
        var r: [TennisDimension: Int] = [:]
        for d in TennisDimension.allCases { r[d] = 3 }
        for w in weaknesses {
            switch w {
            case .backhand:  r[.backhand] = 2
            case .serve:     r[.serve] = 2
            case .netPlay:   r[.net] = 2
            case .ret:       r[.ret] = 2
            case .fitness:   r[.movement] = 2
            case .shotSelection, .mentalGame: break // pressure signals, not strokes
            }
        }
        return r
    }

    /// Mental/shot-selection pain → errors under pressure; otherwise the
    /// modest club default (tentative rather than fearless).
    private var inferredPressure: PressureResponse {
        weaknesses.contains(.mentalGame) || weaknesses.contains(.shotSelection)
            ? .rushErrors
            : .playSafe
    }

    /// The framing goal doubles as "what do you want from tennis".
    private var inferredWant: TennisWant {
        switch goal ?? .winMatches {
        case .winMatches:  return .compete
        case .fixWeakness: return .technique
        case .strategy:    return .compete
        case .climbLevel:  return .consistency
        }
    }

    /// Court-time defaults scaled off experience (the engine wants a value;
    /// weekly-ish is the honest club median).
    private var inferredFrequency: PlayFrequency {
        switch experience ?? .oneToThreeYears {
        case .justStarting, .underOneYear: return .weekly
        case .oneToThreeYears:             return .weekly
        case .threeToTenYears, .tenPlusYears: return .twiceThrice
        }
    }

    /// Match exposure inferred from the self-placed level.
    private var inferredMatchExperience: MatchExperience {
        switch levelSelf ?? .consistentMedium {
        case .learningBasics:      return .socialHits
        case .keepRallyGoing:      return .socialHits
        case .consistentMedium:    return .casualMatches
        case .dependableDirected:  return .casualMatches
        case .depthControlSpin:    return .leagueMatches
        }
    }

    // MARK: Profile build + labor-illusion labels

    /// The user's most representative weakness label, used in the building
    /// screen + result copy.
    private var topWeaknessLabel: String {
        if let w = weaknesses.first {
            return copy.weaknessOption(w)
        }
        return copy.buildGenericFocus
    }

    /// Named labor-illusion steps that reflect the user's real answers.
    private var buildingStepLabels: [String] {
        let levelTitle = builtProfile.map { tpCopy.levelTitle($0.result.level) }
            ?? tpCopy.levelTitle(.intermediate)
        return [
            copy.buildAnalyzingLevel(levelTitle),
            copy.buildMatchingDrills(topWeaknessLabel.lowercased()),
            copy.buildFinalizing,
        ]
    }

    private func buildAndSaveProfile() {
        guard let experience, let levelSelf else { return }

        let answers = TennisProfileAnswers(
            experience: experience,
            frequency: inferredFrequency,
            matchExperience: inferredMatchExperience,
            levelSelf: levelSelf,
            ratings: inferredRatings,
            pressure: inferredPressure,
            want: inferredWant
        )
        // Adopt the engine's suggested goals so the AI Coach + goal tracking
        // have them immediately (the result reveal here is read-only).
        let result = TennisProfileScoring.evaluate(answers)
        let profile = TennisProfile(answers: answers, adoptedGoals: result.suggestedGoals)
        TennisProfileStore.shared.save(profile)
        builtProfile = profile
    }
}

/// Five clay stars that pop in one by one with a spring + tick haptic —
/// the visual drumroll before the review ask. This is OUR rating request,
/// not a claim about existing ratings (App Review 2.3.1 stays happy).
/// Reduce Motion shows all five at rest instantly.
private struct AnimatedStarsRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: "star.fill")
                    .appFont(30, weight: .bold, design: .default)
                    .foregroundStyle(i < shown ? AppPalette.clay : AppPalette.sand)
                    .scaleEffect(i < shown ? 1 : 0.6)
                    .animation(Motion.entrance, value: shown)
            }
        }
        .onAppear {
            guard !reduceMotion else { shown = 5; return }
            for i in 1...5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(i)) {
                    shown = i
                    Haptics.tap()
                }
            }
        }
        .accessibilityHidden(true)
    }
}
