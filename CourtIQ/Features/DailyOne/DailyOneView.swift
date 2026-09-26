import SwiftUI

/// One question. The same one everybody gets today.
///
/// The screen is deliberately shorter than the Daily IQ session: diagram,
/// scenario, three options, one tap. Everything else — why, what the rest of
/// the world said, the streak — arrives *after* the answer, because a player
/// who can see the crowd before choosing is no longer answering the question.
struct DailyOneView: View {
    @EnvironmentObject private var lang: LanguageManager
    @ObservedObject private var store = DailyOneStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Injected so previews and QC can pin a date; nil means today.
    var date: Date = Date()

    @State private var selected: Int?
    @State private var revealed = false
    @State private var crowd: DailyOneCrowd.Split?

    private static let letters = ["A", "B", "C", "D"]

    private var pick: DailyOne.Pick? { DailyOne.pick(for: date) }

    var body: some View {
        ScrollView {
            if let pick {
                content(pick)
            } else {
                Text(lang.t("dailyone.unavailable"))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .padding(40)
            }
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("dailyone.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { restoreIfAnswered() }
    }

    // MARK: Layout

    @ViewBuilder
    private func content(_ pick: DailyOne.Pick) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if let diagram = pick.question.diagram {
                // Situation only. The choreographed play draws the correct
                // shot, so it belongs after the pick — same rule the session
                // screen follows.
                QuizCourtDiagramView(
                    diagram: diagram,
                    play: revealed ? QuizPlayLibrary.play(for: pick.question.id) : nil)
                    .frame(maxWidth: .infinity)
            }

            Text(pick.question.localizedFocusTag(for: lang.language).uppercased())
                .font(.caption.weight(.heavy))
                .kerning(1.1)
                .foregroundStyle(AppPalette.clay)

            Text(pick.question.localizedScenario(for: lang.language))
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            options(pick)

            if revealed {
                revealBlock(pick)
            } else {
                lockButton(pick)
            }
        }
        .padding(20)
        // The tab bar floats over the scroll view; without this the share
        // button sits underneath it on the last screenful.
        .padding(.bottom, 96)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("dailyone.eyebrow"))
                    .font(.caption.weight(.heavy))
                    .kerning(1.2)
                    .foregroundStyle(AppPalette.inkSoft)
                Text(longDate)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppPalette.ink)
            }
            Spacer()
            if store.streak > 0 {
                Label("\(store.streak)", systemImage: "flame.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppPalette.parchment)
                    .clipShape(Capsule())
                    .accessibilityLabel(
                        String(format: lang.t("dailyone.streak_fmt"), store.streak))
            }
        }
    }

    private func options(_ pick: DailyOne.Pick) -> some View {
        let texts = pick.question.localizedOptions(for: lang.language)
        return VStack(spacing: 10) {
            ForEach(texts.indices, id: \.self) { i in
                Button {
                    guard !revealed else { return }
                    Haptics.tap()
                    selected = i
                } label: {
                    optionRow(letter: Self.letters[min(i, Self.letters.count - 1)],
                              text: texts[i], index: i, pick: pick)
                }
                .buttonStyle(.plain)
                // Not `.disabled` — that greys the row out, and after the
                // reveal these rows are the thing the player is reading.
                .allowsHitTesting(!revealed)
            }
        }
    }

    private func optionRow(letter: String, text: String, index: Int,
                           pick: DailyOne.Pick) -> some View {
        let isCorrect = index == pick.correctDisplayedIndex
        let isChosen = index == selected
        // After the reveal the correct row is always marked, and a wrong pick
        // is marked too — showing only the right answer leaves the player
        // guessing whether the app registered what they actually tapped.
        let border: Color = revealed
            ? (isCorrect ? AppPalette.moss : (isChosen ? AppPalette.clay : AppPalette.sand))
            : (isChosen ? AppPalette.clay : AppPalette.sand)
        let width: CGFloat = (revealed ? (isCorrect || isChosen) : isChosen) ? 2.5 : 1

        return HStack(alignment: .top, spacing: 14) {
            Text(letter)
                .font(.headline.weight(.black))
                .foregroundStyle(revealed && isCorrect ? AppPalette.moss : AppPalette.clay)
                .frame(width: 26, alignment: .leading)
            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if revealed {
                Image(systemName: isCorrect ? "checkmark.circle.fill"
                                            : (isChosen ? "xmark.circle.fill" : "circle"))
                    .foregroundStyle(isCorrect ? AppPalette.moss
                                     : (isChosen ? AppPalette.clay : AppPalette.sand))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(border, lineWidth: width))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }

    private func lockButton(_ pick: DailyOne.Pick) -> some View {
        Button {
            submit(pick)
        } label: {
            Text(lang.t("dailyone.lock"))
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppPalette.clay)
        .disabled(selected == nil)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func revealBlock(_ pick: DailyOne.Pick) -> some View {
        let right = selected == pick.correctDisplayedIndex
        VStack(alignment: .leading, spacing: 14) {
            Text(right ? lang.t("dailyone.correct") : lang.t("dailyone.wrong"))
                .font(.title3.weight(.heavy))
                .foregroundStyle(right ? AppPalette.moss : AppPalette.clay)

            crowdLine(pick)

            VStack(alignment: .leading, spacing: 8) {
                Text(lang.t("dailyone.why"))
                    .font(.caption.weight(.heavy))
                    .kerning(1.1)
                    .foregroundStyle(AppPalette.inkSoft)
                Text(pick.question.localizedExplanation(for: lang.language))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(pick.question.localizedTakeaway(for: lang.language))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.parchment)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            ShareLink(item: DailyOneShare.text(pick: pick, streak: store.streak,
                                               lang: lang)) {
                Label(lang.t("dailyone.share"), systemImage: "square.and.arrow.up")
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
        }
        .padding(.top, 4)
    }

    /// What everyone else said — or an honest sentence about why there is no
    /// number yet. A percentage computed from eleven people is noise wearing
    /// the costume of data, so below the threshold this says so instead.
    @ViewBuilder
    private func crowdLine(_ pick: DailyOne.Pick) -> some View {
        if let crowd, crowd.isMeaningful {
            let share = crowd.percentage(forDisplayed: selected ?? 0, in: pick)
            VStack(alignment: .leading, spacing: 6) {
                Text(String(format: lang.t("dailyone.crowd_fmt"), share))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Text(String(format: lang.t("dailyone.crowd_total_fmt"), crowd.total))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
        } else {
            Text(lang.t("dailyone.first_answers"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
        }
    }

    // MARK: Behaviour

    private var longDate: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.language.rawValue)
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return f.string(from: date)
    }

    private func restoreIfAnswered() {
        guard let pick, let entry = store.entry(for: pick.dayKey) else { return }
        selected = pick.originalIndices.firstIndex(of: entry.originalIndex)
        revealed = true
        Task { crowd = await DailyOneCrowd.fetch(dayKey: pick.dayKey) }
    }

    private func submit(_ pick: DailyOne.Pick) {
        guard let choice = selected,
              let original = pick.originalIndex(ofDisplayed: choice) else { return }
        let right = choice == pick.correctDisplayedIndex
        Haptics.tap()
        store.record(dayKey: pick.dayKey, originalIndex: original, correct: right)
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { revealed = true }
        Task { crowd = await DailyOneCrowd.submit(dayKey: pick.dayKey, originalIndex: original) }
    }
}
