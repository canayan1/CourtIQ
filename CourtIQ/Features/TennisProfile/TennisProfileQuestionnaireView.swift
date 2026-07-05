import SwiftUI

/// Multi-step self-assessment that builds a `TennisProfile`. Twelve questions
/// across four steps: background, level self-placement, stroke ratings, and
/// tactical/want. Nothing is pre-selected; the continue button stays disabled
/// until the current step is fully answered, and "See my profile" is enabled
/// only when every answer is set. Visual style mirrors `AICoachConsentView`
/// and `PaywallView`: cream background, parchment cards with a sand stroke,
/// clay-accented selection.
struct TennisProfileQuestionnaireView: View {
    /// When set (a re-assessment launched from the result screen), completion
    /// calls this instead of pushing another result screen. The caller closes
    /// the cover and the store-backed live profile refreshes in place.
    var onFinished: (() -> Void)? = nil

    @EnvironmentObject private var lang: LanguageManager

    private var copy: TennisProfileCopy { TennisProfileCopy(lang: lang.language) }

    // MARK: Steps

    private enum Step: Int, CaseIterable {
        case background      // experience + frequency + match
        case level           // self-placement
        case strokes         // 6 dimension ratings
        case tactical        // pressure + want
    }

    // MARK: Answer state (nothing pre-selected)

    @State private var step: Step = .background

    @State private var experience: TennisExperience?
    @State private var frequency: PlayFrequency?
    @State private var matchExperience: MatchExperience?
    @State private var levelSelf: LevelSelfPlacement?
    @State private var ratings: [TennisDimension: Int] = [:]
    @State private var pressure: PressureResponse?
    @State private var want: TennisWant?

    @State private var builtProfile: TennisProfile?
    @State private var showResult = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                progressHeader

                switch step {
                case .background: backgroundStep
                case .level:      levelStep
                case .strokes:    strokesStep
                case .tactical:   tacticalStep
                }

                navigationButtons
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(copy.sectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showResult) {
            if let profile = builtProfile {
                TennisProfileResultView(profile: profile)
            }
        }
    }

    // MARK: Progress

    private var progressHeader: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? AppPalette.clay : AppPalette.sand)
                    .frame(height: 5)
            }
        }
        .padding(.top, 4)
    }

    // MARK: Step 1 — Background

    private var backgroundStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            questionBlock(copy.qExperience) {
                ForEach(TennisExperience.allCases, id: \.self) { v in
                    optionRow(copy.experienceOption(v), isSelected: experience == v) {
                        experience = v
                    }
                }
            }
            questionBlock(copy.qFrequency) {
                ForEach(PlayFrequency.allCases, id: \.self) { v in
                    optionRow(copy.frequencyOption(v), isSelected: frequency == v) {
                        frequency = v
                    }
                }
            }
            questionBlock(copy.qMatch) {
                ForEach(MatchExperience.allCases, id: \.self) { v in
                    optionRow(copy.matchOption(v), isSelected: matchExperience == v) {
                        matchExperience = v
                    }
                }
            }
        }
    }

    // MARK: Step 2 — Level self-placement

    private var levelStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            questionBlock(copy.qLevel) {
                ForEach(LevelSelfPlacement.allCases, id: \.self) { v in
                    optionRow(copy.levelOption(v), isSelected: levelSelf == v) {
                        levelSelf = v
                    }
                }
            }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .appFont(14, design: .default)
                    .foregroundStyle(AppPalette.clay)
                    .padding(.top, 1)
                Text(copy.provisionalNote)
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

    // MARK: Step 3 — Strokes (1–5 ratings)

    private var strokesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(copy.qStrokesHeader)
                    .font(.title3.bold())
                    .foregroundStyle(AppPalette.ink)
                Text(copy.qStrokesIntro)
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
            Text(copy.dimension(d))
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
                Text(copy.scaleWeak)
                Spacer()
                Text(copy.scaleStrong)
            }
            .font(.caption)
            .foregroundStyle(AppPalette.inkSoft)
        }
    }

    // MARK: Step 4 — Tactical / want

    private var tacticalStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            questionBlock(copy.qPressure) {
                ForEach(PressureResponse.allCases, id: \.self) { v in
                    optionRow(copy.pressureOption(v), isSelected: pressure == v) {
                        pressure = v
                    }
                }
            }
            questionBlock(copy.qWant) {
                ForEach(TennisWant.allCases, id: \.self) { v in
                    optionRow(copy.wantOption(v), isSelected: want == v) {
                        want = v
                    }
                }
            }
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

    // MARK: Navigation buttons

    private var navigationButtons: some View {
        VStack(spacing: 10) {
            if step == .tactical {
                Button {
                    buildAndSaveProfile()
                } label: {
                    Text(copy.seeProfile)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)
                .disabled(!allAnswersComplete)
            } else {
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
            }

            if step != .background {
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
        }
        .padding(.top, 6)
    }

    // MARK: Completion logic

    private var currentStepComplete: Bool {
        switch step {
        case .background:
            return experience != nil && frequency != nil && matchExperience != nil
        case .level:
            return levelSelf != nil
        case .strokes:
            return TennisDimension.allCases.allSatisfy { ratings[$0] != nil }
        case .tactical:
            return pressure != nil && want != nil
        }
    }

    private var allAnswersComplete: Bool {
        experience != nil
            && frequency != nil
            && matchExperience != nil
            && levelSelf != nil
            && TennisDimension.allCases.allSatisfy { ratings[$0] != nil }
            && pressure != nil
            && want != nil
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        withAnimation { step = next }
    }

    private func goBack() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation { step = prev }
    }

    private func buildAndSaveProfile() {
        guard let experience,
              let frequency,
              let matchExperience,
              let levelSelf,
              let pressure,
              let want,
              TennisDimension.allCases.allSatisfy({ ratings[$0] != nil }) else { return }

        let answers = TennisProfileAnswers(
            experience: experience,
            frequency: frequency,
            matchExperience: matchExperience,
            levelSelf: levelSelf,
            ratings: ratings,
            pressure: pressure,
            want: want
        )
        let profile = TennisProfile(answers: answers)
        TennisProfileStore.shared.save(profile)
        if let onFinished {
            onFinished()
        } else {
            builtProfile = profile
            showResult = true
        }
    }
}
