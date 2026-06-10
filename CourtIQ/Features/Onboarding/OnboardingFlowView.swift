import SwiftUI

/// High-conversion, question-heavy onboarding for the hard-paywall model. The
/// flow asks a lot of short questions to build the user's Tennis Profile, runs
/// a labor-illusion "building your plan" beat, reveals a personalized result,
/// makes the "why DropVolley is different" case, then hands off to the paywall via
/// `onComplete`.
///
/// It REUSES the existing Tennis Profile engine — every answer accumulates into
/// a `TennisProfileAnswers`, and at the end a `TennisProfile` is built and saved
/// through `TennisProfileStore.shared`. Visual language mirrors
/// `TennisProfileQuestionnaireView` / `AICoachConsentView`: cream background,
/// parchment cards with a sand stroke, clay-accented selection, one question
/// per screen, nothing pre-selected, Continue disabled until answered.
struct OnboardingFlowView: View {
    @EnvironmentObject private var lang: LanguageManager

    /// Called once the profile is saved and the user taps "See my plan" on the
    /// final evidence slide. The app presents the paywall here.
    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    private var copy: OnboardingCopy { OnboardingCopy(lang: lang.language) }
    private var tpCopy: TennisProfileCopy { TennisProfileCopy(lang: lang.language) }

    // MARK: Ordered steps

    private enum Step: Int, CaseIterable {
        case welcome        // 1  hook
        case goal           // 2  framing goal (flow-local)
        case experience     // 3  TennisExperience
        case frequency      // 4  PlayFrequency
        case match          // 5  MatchExperience
        case level          // 6  LevelSelfPlacement (+ provisional note)
        case strokes        // 7  6 dimension 1–5 ratings
        case weaknesses     // 8  pain points (flow-local, multi-select)
        case sliders        // 9  behavioral sliders → PressureResponse
        case want           // 10 TennisWant
        case commitment     // 11 drills/day (flow-local Int)
        case building       // 12 labor illusion
        case result         // 13 personalized reveal
        case evidence       // 14 "why DropVolley is different" carousel
    }

    /// Steps that show the top progress bar + Back/Continue chrome. Welcome and
    /// the building/result/evidence screens own their own layout.
    private var questionSteps: [Step] {
        [.goal, .experience, .frequency, .match, .level, .strokes, .weaknesses, .sliders, .want, .commitment]
    }

    @State private var step: Step = .welcome

    // MARK: Answer state — nothing pre-selected

    // Flow-local
    @State private var goal: OnboardingGoal?
    @State private var weaknesses: Set<OnboardingWeakness> = []
    @State private var commitment: Int?

    // Tennis Profile engine inputs
    @State private var experience: TennisExperience?
    @State private var frequency: PlayFrequency?
    @State private var matchExperience: MatchExperience?
    @State private var levelSelf: LevelSelfPlacement?
    @State private var ratings: [TennisDimension: Int] = [:]
    @State private var want: TennisWant?

    // Behavioral sliders (0...1). Default 0.5 = neutral; user must move them.
    @State private var patience: Double = 0.5    // 0 rush → 1 patient
    @State private var tactics: Double = 0.5     // 0 react → 1 tactical
    @State private var aggression: Double = 0.5  // 0 safe → 1 go for it
    @State private var slidersTouched = false

    @State private var builtProfile: TennisProfile?

    var body: some View {
        Group {
            switch step {
            case .welcome:
                welcomeScreen
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
            case .evidence:
                evidenceScreen
            default:
                questionScaffold
            }
        }
        .background(AppPalette.cream)
        .animation(.easeInOut, value: step)
    }

    // MARK: 1 — Welcome / hook

    private var welcomeScreen: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            ZStack {
                Circle().fill(AppPalette.clay.opacity(0.14)).frame(width: 72, height: 72)
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AppPalette.clay)
            }

            Text(copy.welcomeTitle)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(copy.welcomeBullets, id: \.self) { line in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppPalette.moss)
                            .padding(.top, 1)
                        Text(line)
                            .font(.body)
                            .foregroundStyle(AppPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }

            Spacer()

            Button {
                advance()
            } label: {
                Text(copy.getStarted)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppPalette.cream)
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
        case .frequency:   frequencyStep
        case .match:       matchStep
        case .level:       levelStep
        case .strokes:     strokesStep
        case .weaknesses:  weaknessesStep
        case .sliders:     slidersStep
        case .want:        wantStep
        case .commitment:  commitmentStep
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

    // MARK: 4 — Frequency

    private var frequencyStep: some View {
        questionBlock(tpCopy.qFrequency) {
            ForEach(PlayFrequency.allCases, id: \.self) { v in
                optionRow(tpCopy.frequencyOption(v), isSelected: frequency == v) { frequency = v }
            }
        }
    }

    // MARK: 5 — Match play

    private var matchStep: some View {
        questionBlock(tpCopy.qMatch) {
            ForEach(MatchExperience.allCases, id: \.self) { v in
                optionRow(tpCopy.matchOption(v), isSelected: matchExperience == v) { matchExperience = v }
            }
        }
    }

    // MARK: 6 — Level self-placement (+ provisional note)

    private var levelStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            questionBlock(tpCopy.qLevel) {
                ForEach(LevelSelfPlacement.allCases, id: \.self) { v in
                    optionRow(tpCopy.levelOption(v), isSelected: levelSelf == v) { levelSelf = v }
                }
            }
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14))
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

    // MARK: 7 — Strokes (1–5 ratings)

    private var strokesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(tpCopy.qStrokesHeader)
                    .font(.title3.bold())
                    .foregroundStyle(AppPalette.ink)
                Text(tpCopy.qStrokesIntro)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            VStack(spacing: 14) {
                ForEach(TennisDimension.allCases) { d in
                    ratingRow(d)
                }
            }
            .padding(16)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func ratingRow(_ d: TennisDimension) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tpCopy.dimension(d))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    let isSelected = ratings[d] == value
                    Button {
                        ratings[d] = value
                    } label: {
                        Text("\(value)")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(isSelected ? AppPalette.clay : AppPalette.cream)
                            .foregroundStyle(isSelected ? AppPalette.parchment : AppPalette.ink)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? AppPalette.clay : AppPalette.sand, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text(tpCopy.scaleWeak)
                Spacer()
                Text(tpCopy.scaleStrong)
            }
            .font(.caption)
            .foregroundStyle(AppPalette.inkSoft)
        }
    }

    // MARK: 8 — Weaknesses (multi-select pain points)

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

    // MARK: 9 — Behavioral sliders → PressureResponse

    private var slidersStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(copy.slidersTitle)
                    .font(.title3.bold())
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(copy.slidersIntro)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            VStack(spacing: 16) {
                sliderRow(left: copy.sliderPatienceLeft, right: copy.sliderPatienceRight, value: $patience)
                sliderRow(left: copy.sliderTacticsLeft, right: copy.sliderTacticsRight, value: $tactics)
                sliderRow(left: copy.sliderAggressionLeft, right: copy.sliderAggressionRight, value: $aggression)
            }
            .padding(16)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func sliderRow(left: String, right: String, value: Binding<Double>) -> some View {
        VStack(spacing: 8) {
            Slider(value: value, in: 0...1) { editing in
                if editing { slidersTouched = true }
            }
            .tint(AppPalette.clay)
            HStack {
                Text(left)
                Spacer()
                Text(right)
            }
            .font(.caption)
            .foregroundStyle(AppPalette.inkSoft)
        }
    }

    // MARK: 10 — What you want

    private var wantStep: some View {
        questionBlock(tpCopy.qWant) {
            ForEach(TennisWant.allCases, id: \.self) { v in
                optionRow(tpCopy.wantOption(v), isSelected: want == v) { want = v }
            }
        }
    }

    // MARK: 11 — Commitment

    private var commitmentStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(copy.commitmentQuestion)
                .font(.title3.bold())
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                ForEach([1, 2, 3], id: \.self) { n in
                    let isSelected = commitment == n
                    Button {
                        commitment = n
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 72)
                            .background(isSelected ? AppPalette.clay : AppPalette.parchment)
                            .foregroundStyle(isSelected ? AppPalette.parchment : AppPalette.ink)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isSelected ? AppPalette.clay : AppPalette.sand, lineWidth: isSelected ? 2 : 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let n = commitment {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(AppPalette.clay)
                    Text(copy.commitmentFeedback(n))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(AppPalette.clay.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.opacity)
            }
        }
    }

    // MARK: 14 — Evidence carousel

    private var evidenceScreen: some View {
        let slides = copy.evidenceSlides
        return VStack(spacing: 0) {
            TabView {
                ForEach(Array(slides.enumerated()), id: \.offset) { _, slide in
                    VStack(alignment: .leading, spacing: 18) {
                        Spacer()
                        Text(slide.headline)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(slide.support)
                            .font(.title3)
                            .foregroundStyle(AppPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                onComplete()
            } label: {
                Text(copy.seeMyPlan)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(AppPalette.cream)
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
                    .font(.system(size: 20))
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
        .buttonStyle(.plain)
    }

    private func multiSelectRow(_ title: String, isSelected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
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
        .buttonStyle(.plain)
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
        case .welcome, .building, .result, .evidence:
            return true
        case .goal:        return goal != nil
        case .experience:  return experience != nil
        case .frequency:   return frequency != nil
        case .match:       return matchExperience != nil
        case .level:       return levelSelf != nil
        case .strokes:     return TennisDimension.allCases.allSatisfy { ratings[$0] != nil }
        case .weaknesses:  return !weaknesses.isEmpty
        case .sliders:     return slidersTouched
        case .want:        return want != nil
        case .commitment:  return commitment != nil
        }
    }

    // MARK: Step transitions

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        // Build + save the profile exactly when we leave the last question
        // (commitment) and enter the building screen.
        if step == .commitment {
            buildAndSaveProfile()
        }
        withAnimation { step = next }
    }

    private func goBack() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation { step = prev }
    }

    // MARK: Slider → PressureResponse mapping

    /// Collapses the three behavioral sliders into the single `PressureResponse`
    /// the Tennis Profile engine expects:
    ///   • high patience + high tactical → `.patientPick`
    ///   • high aggression (and not clearly patient/tactical) → `.goForIt`
    ///   • low aggression (plays it safe) → `.playSafe`
    ///   • otherwise (low patience / reactive) → `.rushErrors`
    private var derivedPressure: PressureResponse {
        let patient = patience >= 0.6
        let tactical = tactics >= 0.6
        let aggressive = aggression >= 0.6
        let safe = aggression <= 0.4
        let rushed = patience <= 0.4

        if patient && tactical { return .patientPick }
        if aggressive { return .goForIt }
        if safe { return .playSafe }
        if rushed { return .rushErrors }
        // Neutral-ish: lean on the tactical read, else treat as safe.
        return tactical ? .patientPick : .playSafe
    }

    // MARK: Profile build + labor-illusion labels

    /// The user's most representative weakness label, used in the building
    /// screen + result copy. Prefers an explicit pain point; falls back to the
    /// lowest-rated stroke dimension; else a generic word.
    private var topWeaknessLabel: String {
        if let w = weaknesses.first {
            return copy.weaknessOption(w)
        }
        if let lowest = TennisDimension.allCases
            .filter({ ratings[$0] != nil })
            .min(by: { (ratings[$0] ?? 3) < (ratings[$1] ?? 3) }) {
            return tpCopy.dimension(lowest)
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
            copy.buildCalibrating(commitment ?? 1),
            copy.buildFinalizing,
        ]
    }

    private func buildAndSaveProfile() {
        guard let experience,
              let frequency,
              let matchExperience,
              let levelSelf,
              let want,
              TennisDimension.allCases.allSatisfy({ ratings[$0] != nil }) else { return }

        let answers = TennisProfileAnswers(
            experience: experience,
            frequency: frequency,
            matchExperience: matchExperience,
            levelSelf: levelSelf,
            ratings: ratings,
            pressure: derivedPressure,
            want: want
        )
        // Adopt the engine's suggested goals so the AI Coach + goal tracking
        // have them immediately (the result reveal here is read-only).
        let result = TennisProfileScoring.evaluate(answers)
        let profile = TennisProfile(answers: answers, adoptedGoals: result.suggestedGoals)
        TennisProfileStore.shared.save(profile)
        builtProfile = profile
    }
}
