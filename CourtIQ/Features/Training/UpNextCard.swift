import SwiftUI

/// The next training session, on Home, without asking for it.
///
/// Before this, reaching a workout meant: scroll Home past six full-bleed
/// cards, find a row headed ALSO, scroll that row sideways, tap *Programs*,
/// tap a program, tap a week, tap an exercise. Four taps and three scrolls to
/// read a page — and no way at all to actually *do* the session, because there
/// was no runner. The thing the player came to the app to do was the hardest
/// thing in it to reach.
///
/// The model is Weather's hourly strip: the useful content is on the first
/// screen, already visible, and the horizontal rail means you can read the
/// whole session without opening anything. One tap starts it.
///
/// It appears only when there is an active program. A player who has never
/// opened one sees nothing here rather than an advert for a locked feature.
struct UpNextCard: View {
    @EnvironmentObject private var lang: LanguageManager
    @ObservedObject private var progress = TrainingProgressManager.shared

    /// Opens the full program (the old detail screen, still the place for the
    /// week view and check-ins).
    let onOpenProgram: (TrainingProgram) -> Void

    @State private var running: RunnerTarget?

    private struct RunnerTarget: Identifiable {
        let program: TrainingProgram
        let day: TrainingDayPlan
        var id: String { "\(program.id)|\(day.id)" }
    }

    private var program: TrainingProgram? {
        guard let id = progress.activeProgramID else { return nil }
        return TrainingProgram.allPrograms.first { $0.id == id }
    }

    var body: some View {
        if let program, let day = progress.nextDay(in: program) {
            card(program: program, day: day)
                .fullScreenCover(item: $running) { target in
                    SessionRunnerView(program: target.program, day: target.day)
                        .environmentObject(lang)
                }
        }
    }

    private func card(program: TrainingProgram, day: TrainingDayPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Eyebrow(progress.weekIsComplete(program)
                        ? lang.t("upnext.week_done")
                        : lang.t("upnext.eyebrow"))
                Spacer()
                Button {
                    onOpenProgram(program)
                } label: {
                    Text(lang.t("upnext.open_program"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.clay)
                }
            }

            Text(day.localizedTitle(for: lang.language))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            // Type, length and focus on one line — the three things that decide
            // whether you have time for this right now.
            Text("\(day.type.title) · \(day.duration) · \(day.localizedFocus(for: lang.language))")
                .font(.footnote)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if !day.exercises.isEmpty { exerciseRail(day) }

            PrimaryButton(title: lang.t("upnext.start"), icon: "play.fill") {
                AppAnalytics.shared.log(AnalyticsEvent.sessionStarted,
                                        ["program": program.id, "day": day.id, "from": "home"])
                running = RunnerTarget(program: program, day: day)
            }
        }
        .padding(18)
        .cardSurface(cornerRadius: 22)
    }

    /// The session, readable without a tap. Weather does not make you open the
    /// forecast to find out about three o'clock.
    private func exerciseRail(_ day: TrainingDayPlan) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(day.exercises.enumerated()), id: \.element.id) { i, ex in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(i + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppPalette.clay)
                        Text(ex.localizedTitle(for: lang.language))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Text(ex.prescription)
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(AppPalette.inkSoft)
                            .lineLimit(1)
                    }
                    .frame(width: 104, height: 84, alignment: .topLeading)
                    .padding(10)
                    .background(AppPalette.parchment)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(format: lang.t("upnext.rail_a11y_fmt"), day.exercises.count))
    }
}
