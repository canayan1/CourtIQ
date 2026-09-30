import SwiftUI

/// Doing the session, as opposed to reading about it.
///
/// Until this existed there was no "doing" mode anywhere in the app. A training
/// day was a document: goal, objective, warm-up, a list of exercises, a
/// finisher, recovery — all stacked on one scrolling page. The player's real
/// workflow was to read the wall of text, put the phone in a bag, and try to
/// remember what came third. Every other part of the app has a thing you *do*;
/// training had a thing you *study*.
///
/// So this is one step per screen, and the step you are on is the only thing on
/// it. The prescription — "3 × 8", "40s each side" — is set in the largest type
/// on the page, because it is the one line you read mid-set with your heart
/// rate up and the phone propped against a water bottle.
///
/// There is no timer. `prescription` is free text written by a coach and most
/// of it is reps, not seconds; a countdown would be honest for perhaps a third
/// of the exercises and a lie for the rest. Guessing which is which from a
/// string is the kind of cleverness that fails silently in a gym.
struct SessionRunnerView: View {
    let program: TrainingProgram
    let day: TrainingDayPlan

    @EnvironmentObject private var lang: LanguageManager
    @ObservedObject private var progress = TrainingProgressManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step = 0

    /// Warm-up, the exercises, the finisher, and the page that says you're done.
    /// Recovery rides along on the last page rather than taking one of its own:
    /// it is what you do after putting the phone down.
    private enum Step: Equatable {
        case warmup(String)
        case exercise(TrainingExercise, index: Int, of: Int)
        case finisher(String)
        case done
    }

    private var steps: [Step] {
        var out: [Step] = []
        let warm = day.localizedWarmup(for: lang.language)
        if !warm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out.append(.warmup(warm))
        }
        for (i, ex) in day.exercises.enumerated() {
            out.append(.exercise(ex, index: i, of: day.exercises.count))
        }
        let fin = day.localizedFinisher(for: lang.language)
        if !fin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            out.append(.finisher(fin))
        }
        out.append(.done)
        return out
    }

    private var isLastBeforeDone: Bool { step == steps.count - 2 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressRail
                TabView(selection: $step) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, s in
                        page(for: s).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                advanceBar
            }
            .background(AppPalette.cream)
            .navigationTitle(day.localizedTitle(for: lang.language))
            .navigationBarTitleDisplayMode(.inline)
            .trackScreen("SessionRunner")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // "Done" and not a cross: leaving half-way through is a
                    // normal way to finish a session, not an error state.
                    Button(lang.t("common.done")) { dismiss() }
                        .foregroundStyle(AppPalette.clay)
                }
            }
        }
    }

    // MARK: - Chrome

    /// One segment per step. Deliberately not a percentage: "4 of 9" is a
    /// number you can hold, 44% is not.
    private var progressRail: some View {
        HStack(spacing: 4) {
            ForEach(steps.indices, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? AppPalette.clay : AppPalette.sand)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .accessibilityElement()
        .accessibilityLabel(String(format: lang.t("runner.progress_fmt"), step + 1, steps.count))
    }

    private var advanceBar: some View {
        Group {
            if case .done = steps[min(step, steps.count - 1)] {
                EmptyView()
            } else {
                PrimaryButton(title: isLastBeforeDone ? lang.t("runner.finish") : lang.t("runner.next"),
                              icon: isLastBeforeDone ? "checkmark" : "arrow.right") {
                    withAnimation(reduceMotion ? nil : Motion.entrance) {
                        step = min(step + 1, steps.count - 1)
                    }
                }
                .padding(20)
            }
        }
    }

    // MARK: - Pages

    @ViewBuilder
    private func page(for s: Step) -> some View {
        switch s {
        case .warmup(let text):
            simplePage(eyebrow: lang.t("runner.warmup"),
                       title: lang.t("runner.warmup_title"),
                       body: text,
                       icon: "figure.cooldown")
        case .finisher(let text):
            simplePage(eyebrow: lang.t("runner.finisher"),
                       title: lang.t("runner.finisher_title"),
                       body: text,
                       icon: "flame.fill")
        case .exercise(let ex, let index, let total):
            exercisePage(ex, index: index, total: total)
        case .done:
            donePage
        }
    }

    private func simplePage(eyebrow: String, title: String, body: String, icon: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow(eyebrow)
                HStack(spacing: 10) {
                    Image(systemName: icon).foregroundStyle(AppPalette.clay)
                    Text(title)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(AppPalette.ink)
                }
                Text(body)
                    .font(.body)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private func exercisePage(_ ex: TrainingExercise, index: Int, total: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Eyebrow(String(format: lang.t("runner.exercise_fmt"), index + 1, total))

                Text(ex.localizedTitle(for: lang.language))
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                // The one line that matters with the phone on the floor.
                Text(ex.prescription)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(AppPalette.clay)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(String(format: lang.t("runner.prescription_a11y_fmt"), ex.prescription))

                Text(ex.localizedIntent(for: lang.language))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                if let how = ex.localizedHowTo(for: lang.language), !how.isEmpty {
                    bulletCard(title: lang.t("runner.how"), items: how, icon: "list.number")
                }
                if let watch = ex.localizedWatchOuts(for: lang.language), !watch.isEmpty {
                    bulletCard(title: lang.t("runner.watch"), items: watch, icon: "exclamationmark.triangle.fill")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private func bulletCard(title: String, items: [String], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.caption)
                Text(title).font(.caption.weight(.bold)).textCase(.uppercase)
            }
            .foregroundStyle(AppPalette.inkSoft)

            ForEach(Array(items.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 8) {
                    Text("•").foregroundStyle(AppPalette.clay)
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cardSurface(cornerRadius: 18)
    }

    private var donePage: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppPalette.clay)
            Text(lang.t("runner.done_title"))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(AppPalette.ink)
                .multilineTextAlignment(.center)

            let recovery = day.localizedRecovery(for: lang.language)
            if !recovery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill").font(.caption)
                        Text(lang.t("runner.recovery")).font(.caption.weight(.bold)).textCase(.uppercase)
                    }
                    .foregroundStyle(AppPalette.inkSoft)
                    Text(recovery)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .cardSurface(cornerRadius: 18)
            }

            PrimaryButton(title: lang.t("common.done"), icon: "checkmark") { dismiss() }
        }
        .padding(24)
        .onAppear {
            // Reaching this page IS the completion. Asking someone to also tick
            // a box afterwards is asking them to report to the app.
            progress.markCompleted(programID: program.id,
                                   week: progress.selectedWeek,
                                   dayID: day.id)
            AppAnalytics.shared.log(AnalyticsEvent.sessionCompleted,
                                    ["program": program.id, "day": day.id])
        }
    }
}
