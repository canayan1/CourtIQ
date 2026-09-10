import SwiftUI

/// The lesson as a readable page: the rule, the diagram, the beats, and — when
/// `showsQuiz` is on — the scenario question.
///
/// Since Rocco arrived this is no longer the main flow. `DialogueView` teaches;
/// this is the **Notes** view behind the toolbar button, for a player who wants
/// the whole thing in one scroll before a match. It keeps the quiz path because
/// it is also the fallback if the conversation is ever unavailable.
struct LessonView: View {
    let chapter: Chapter
    let lesson: Lesson
    /// Off in Notes mode: reading the reference material must not be a second,
    /// competing way to complete the lesson and bank XP.
    var showsQuiz: Bool = true

    @Environment(PlayerProgress.self) private var progress
    @EnvironmentObject private var lang: LanguageManager
    private var copy: TacticsCopy { TacticsCopy(lang: lang.language) }
    @Environment(TacticsAccess.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss

    private enum Phase { case teach, decide }

    @State private var phase: Phase = .teach
    @State private var picked: Int?
    @State private var attempts = 0
    @State private var showCompletion = false
    @State private var showPaywall = false

    /// Whether the lesson was already done when this screen opened. Latched on
    /// appear, because `completeLesson` flips the underlying flag mid-session and
    /// the completion sheet would otherwise always claim to be a review.
    @State private var wasAlreadyDone: Bool?

    /// XP is only awarded the first time; a review pass says so up front rather
    /// than dangling a reward it won't give.
    private var isReview: Bool { wasAlreadyDone ?? progress.isCompleted(lesson.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch phase {
                case .teach:  teachPhase
                case .decide: decidePhase
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AppPalette.cream)
        .navigationTitle(copy.chapter(chapter.number))
        .navigationBarTitleDisplayMode(.inline)
        .animation(Motion.reveal, value: phase)
        .animation(Motion.reveal, value: picked)
        .onAppear {
            if wasAlreadyDone == nil { wasAlreadyDone = progress.isCompleted(lesson.id) }
        }
        .sheet(isPresented: $showCompletion) {
            LessonCompleteView(
                chapter: chapter,
                lesson: lesson,
                firstTry: attempts == 1,
                wasReview: isReview
            ) {
                showCompletion = false
                dismiss()
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showPaywall) {
            TacticsPaywallSheet()
        }
    }

    // MARK: Teach

    private var teachPhase: some View {
        VStack(alignment: .leading, spacing: 20) {
            // The five-part scheme, in its fixed order: situation → principle →
            // default action → adjustments → common mistake. The principle keeps
            // the hero treatment — it is the one line worth remembering — while
            // the situation sits above it so the reader is standing inside the
            // point before the rule lands.
            section(copy.theSituation, lesson.situation)

            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(isReview ? copy.reviewPrinciple : copy.thePrinciple,
                        tint: .white.opacity(0.85))
                Text(lesson.principle)
                    .appFont(22, weight: .bold, relativeTo: .title3)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(AppPalette.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text(lesson.title)
                .appFont(28, weight: .heavy, relativeTo: .title)
                .foregroundStyle(AppPalette.ink)

            if let diagram = lesson.diagram {
                CourtDiagram(scene: diagram)
                    .padding(16)
                    .cardSurface()
            }

            section(copy.yourDefault, lesson.defaultAction)

            if !lesson.adjustments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(copy.adjustWhen, tint: AppPalette.clayText)
                    ForEach(Array(lesson.adjustments.enumerated()), id: \.offset) { _, adjustment in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(adjustment.when)
                                .font(.system(.footnote, design: .rounded).weight(.heavy))
                                .foregroundStyle(AppPalette.clayText)
                            Text(adjustment.then)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(AppPalette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .cardSurface()
                .transition(.opacity)
            }

            section(copy.theCommonMistake, lesson.commonMistake)

            // The "Going further" note is part of the one subscription.
            // Subscribers see it in full; everyone else sees a locked teaser
            // that opens the paywall — the intermediate-player hook: a strong
            // player demoing the free chapter finds the beginner rule obvious,
            // then hits "the exception, and what better players do" locked.
            if let advanced = lesson.advanced {
                if subscriptions.isSubscribed {
                    advancedCard(advanced)
                } else {
                    Button { showPaywall = true } label: {
                        advancedTeaser(advanced.heading)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showsQuiz {
                PrimaryButton(title: copy.tryItInAPoint, icon: "arrow.right") {
                    phase = .decide
                }
                .padding(.top, 4)
            }
        }
    }

    /// One titled card of the scheme.
    private func section(_ heading: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(heading, tint: AppPalette.clayText)
            Text(body)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardSurface()
        .transition(.opacity)
    }

    // MARK: Advanced ("Going further") layer

    private func advancedCard(_ note: AdvancedNote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(note.heading, tint: AppPalette.clayText)
            Text(note.body)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .overlay(alignment: .topTrailing) {
            Image(systemName: "arrow.up.forward.circle.fill")
                .foregroundStyle(AppPalette.clayText.opacity(0.5))
                .padding(14)
        }
        .cardSurface()
        .transition(.opacity)
    }

    private func advancedTeaser(_ heading: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundStyle(AppPalette.clayText)
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(heading, tint: AppPalette.clayText)
                Text(copy.advancedBody)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(AppPalette.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(AppPalette.ink.opacity(0.4))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardSurface()
    }

    // MARK: Decide

    private var decidePhase: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow(copy.situation, tint: AppPalette.clayText)
                Text(lesson.quiz.scenario)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .cardSurface()

            // Only a diagram authored for the question itself. Re-showing the
            // teaching diagram would both hand over the answer and push the
            // options below the fold.
            if let diagram = lesson.quiz.diagram {
                CourtDiagram(scene: diagram)
                    .padding(16)
                    .cardSurface()
            }

            Text(lesson.quiz.question)
                .appFont(22, weight: .heavy, relativeTo: .title3)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ForEach(Array(lesson.quiz.options.enumerated()), id: \.offset) { index, option in
                    optionRow(index: index, text: option)
                }
            }

            if let picked {
                feedback(correct: picked == lesson.quiz.correctIndex)
            }
        }
    }

    private static let optionLetters = ["A", "B", "C", "D", "E"]

    private func optionRow(index: Int, text: String) -> some View {
        let isPicked = picked == index
        let isCorrect = index == lesson.quiz.correctIndex
        let revealed = picked != nil

        // Only the picked answer is colored: revealing the right one on a wrong
        // guess would remove the reason to think again on the retry.
        let stroke: Color = revealed && isPicked
            ? (isCorrect ? AppPalette.mossDeep : AppPalette.alert)
            : AppPalette.sand

        let fill: Color = {
            guard revealed, isPicked else { return AppPalette.parchment }
            return isCorrect ? AppPalette.mossTint : AppPalette.clayTint
        }()

        return Button {
            select(index)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(revealed && isPicked
                              ? (isCorrect ? AppPalette.mossDeep : AppPalette.alert)
                              : AppPalette.cream)
                        .frame(width: 26, height: 26)
                    if revealed && isPicked {
                        Image(systemName: isCorrect ? "checkmark" : "xmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                    } else {
                        Text(Self.optionLetters[index % Self.optionLetters.count])
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                }

                Text(text)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(AppPalette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .cardSurface(fill: fill, stroke: stroke, cornerRadius: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableCardStyle())
        // A correct answer freezes the options so the explanation is the only
        // thing left to act on.
        .disabled(picked == lesson.quiz.correctIndex)
    }

    @ViewBuilder
    private func feedback(correct: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: correct ? "checkmark.seal.fill" : "arrow.counterclockwise")
                    .font(.headline)
                Text(correct ? (attempts == 1 ? copy.exactlyRight : copy.thatsIt) : copy.notHighestPercentage)
                    .font(.system(.headline, design: .rounded).weight(.bold))
            }
            .foregroundStyle(correct ? AppPalette.mossText : AppPalette.clayText)

            if correct {
                Text(lesson.quiz.explanation)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryButton(
                    title: isReview ? copy.done : copy.completeLesson,
                    icon: "checkmark",
                    tint: AppPalette.mossDeep
                ) {
                    finish()
                }
            } else {
                Text(copy.lookAgain)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(AppPalette.ink)

                HStack(spacing: 12) {
                    Button {
                        Haptics.tap()
                        picked = nil
                    } label: {
                        Text(copy.tryAgain)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(AppPalette.clay)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(PressableCardStyle())

                    Button {
                        Haptics.tap()
                        picked = nil
                        phase = .teach
                    } label: {
                        Text(copy.rereadRule)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(AppPalette.clayText)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .cardSurface(
            fill: correct ? AppPalette.mossTint : AppPalette.clayTint,
            stroke: correct ? AppPalette.mossDeep.opacity(0.4) : AppPalette.clay.opacity(0.4)
        )
    }

    // MARK: Actions

    private func select(_ index: Int) {
        guard picked != lesson.quiz.correctIndex else { return }
        attempts += 1
        picked = index
        if index == lesson.quiz.correctIndex {
            Haptics.success()
            Sound.play(.correct)
        } else {
            Haptics.error()
            Sound.play(.wrong)
        }
    }

    private func finish() {
        progress.completeLesson(lesson, in: chapter, firstTry: attempts == 1)
        Haptics.celebrate()
        showCompletion = true
    }
}
