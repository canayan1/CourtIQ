import SwiftUI

/// Record a session with the phone worn on the body.
///
/// The screen is deliberately plain, because nobody looks at it while it runs
/// — the phone is in a belt strap facing the fence. What matters is that
/// starting takes one tap after picking the drill, that stopping is
/// unmissable with sweaty hands, and that the summary afterwards is honest
/// about which numbers it could not produce.
struct BodySessionView: View {
    @StateObject private var recorder = BodySessionRecorder()
    @State private var drill: DrillContext.Kind = .freePlay
    @State private var result: BodySessionResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if recorder.state == .running {
                    running
                } else if let result {
                    summary(result)
                } else {
                    setup
                }
            }
            .padding(20)
        }
        .background(AppPalette.parchment.ignoresSafeArea())
        .navigationTitle("Session")
    }

    // MARK: - Before

    private var setup: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Strap the phone at your waist, screen in, and play.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppPalette.ink)

            // Saying what the drill is removes the one thing the sensors
            // cannot resolve. A phone at the waist cannot tell a cross-court
            // forehand from a down-the-line one, so a swing rate that falls
            // halfway through is ambiguous — tiring, or changing shot? — and
            // this answers it before the session starts rather than guessing
            // afterwards.
            Text("What are you about to do?")
                .font(.headline)
                .foregroundStyle(AppPalette.inkSoft)
            Picker("Drill", selection: $drill) {
                ForEach(DrillContext.Kind.allCases, id: \.self) { kind in
                    Text(label(for: kind)).tag(kind)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()

            if let failure = recorder.failure {
                Text(failure)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.alert)
            }

            Button {
                result = nil
                recorder.start(drill: DrillContext(kind: drill, note: nil, plannedMinutes: nil))
            } label: {
                Text("Start")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)

            Text("The microphone listens for ball contact and is never recorded. "
                 + "What is kept is the moment of each strike and how loud it was — "
                 + "nothing is written to disk and nothing is sent anywhere.")
                .font(.footnote)
                .foregroundStyle(AppPalette.inkSoft)
        }
    }

    // MARK: - During

    private var running: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(timeString(recorder.elapsed))
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppPalette.ink)

            HStack(spacing: 28) {
                counter("Contacts", recorder.strokes)
                counter("Split steps", recorder.splitStepCount)
            }

            Text("Recording. Put the phone away — nothing here needs looking at.")
                .font(.footnote)
                .foregroundStyle(AppPalette.inkSoft)

            Button(role: .destructive) {
                result = recorder.stop()
            } label: {
                Text("Stop")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 64)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.alert)
        }
    }

    private func counter(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppPalette.clay)
            Text(title)
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
        }
    }

    // MARK: - After

    @ViewBuilder
    private func summary(_ r: BodySessionResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(label(for: r.drill.kind))
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
            Text("\(timeString(r.duration)) · \(r.impacts.count) contacts heard")
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)

            row("Split steps", "\(r.splitSteps.count)")
            row("Efforts", "\(r.efforts)")
            if let share = r.workShare {
                row("Time moving", String(format: "%.0f%%", share * 100))
            }
            if let rest = r.longestRest {
                row("Longest rest", String(format: "%.0f s", rest))
            }

            // The readiness number is the one this whole session exists for,
            // and it is also the one most likely to be unavailable — it needs
            // the opponent's contacts, which needs the microphone to have
            // heard two players clearly enough to tell apart. When that did
            // not happen the screen says so instead of showing a share of
            // nothing.
            if let readiness = r.readiness {
                row("Ready for the ball",
                    String(format: "%.0f%% (%d of %d)",
                           readiness.share * 100, readiness.matched, readiness.total))
            } else {
                Text(unavailableReadiness(r))
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .padding(.top, 4)
            }

            Button("Done") { result = nil }
                .buttonStyle(.bordered)
                .tint(AppPalette.clay)
                .padding(.top, 8)
        }
    }

    private func unavailableReadiness(_ r: BodySessionResult) -> String {
        if r.attribution == nil {
            return "Not measuring how ready you were: the strokes did not separate "
                 + "into two players. That is expected on a wall or a solo feed, "
                 + "where every contact is the same distance from the phone."
        }
        return "Not measuring how ready you were: too few of your opponent's "
             + "contacts were heard to put a number on it."
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(AppPalette.inkSoft)
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(AppPalette.ink)
        }
        .font(.subheadline)
    }

    private func label(for kind: DrillContext.Kind) -> String {
        switch kind {
        case .freePlay: return "Free play"
        case .crossCourtForehand: return "Cross-court forehands"
        case .crossCourtBackhand: return "Cross-court backhands"
        case .serve: return "Serving"
        case .volley: return "Volleys"
        case .wall: return "Wall"
        case .match: return "Match"
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
