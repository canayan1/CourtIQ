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
            // Chips rather than a wheel. Seven options in an inline Picker
            // renders as a cramped wheel that shows four and hides the rest —
            // including Wall and Match, which are the two a player is most
            // likely to want. Chips show all seven and match the Home screen.
            FlowChips(kinds: DrillContext.Kind.allCases, selection: $drill, label: label)

            if let failure = recorder.failure {
                Text(failure)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.alert)
            }

            Button {
                result = nil
                recorder.start(drill: DrillContext(kind: drill))
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

            if let rhythm = r.rhythm {
                row("Longest rally", "\(rhythm.longestRally) strokes")
                row("Rallies", "\(rhythm.rallies.count)")
                row("Tempo", String(format: "%.2f s between strokes", rhythm.medianInterval))
                row("Tempo steadiness",
                    String(format: "%.0f%% spread", rhythm.tempoSpread * 100))
            }
            if r.drill.kind == .wall {
                if let rebounds = r.wallRebounds {
                    row("Rebounds heard", "\(rebounds)")
                } else {
                    Text("Could not tell your racket from the ball coming off the "
                         + "wall: both arrived at the microphone at much the same "
                         + "volume. In a pocket they should be far apart, so this "
                         + "is worth checking against your own count.")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }

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
            if r.drill.kind == .wall {
                // Readiness compares the player's hops with the OPPONENT's
                // contacts, and a wall does not have contacts of its own to
                // compare against — the rebound is the player's own ball
                // coming back. Silence here is correct.
                EmptyView()
            } else if let readiness = r.readiness {
                row("Ready for the ball",
                    String(format: "%.0f%% (%d of %d)",
                           readiness.share * 100, readiness.matched, readiness.total))
            } else {
                Text(unavailableReadiness(r))
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .padding(.top, 4)
            }

            if !r.findings.findings.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Where to look")
                    .font(.headline)
                    .foregroundStyle(AppPalette.ink)
                ForEach(r.findings.findings, id: \.kind.rawValue) { finding in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(finding.weight == .clear ? AppPalette.clay : AppPalette.gold)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                        Text(finding.sentence)
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.ink)
                    }
                }
            } else if r.findings.notChecked.isEmpty {
                Text("Nothing to flag in this one.")
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.moss)
                    .padding(.top, 4)
            }

            // Always shown, never collapsed away. A session with no flags and
            // a long list here is not a session played well — it is a session
            // nobody looked at, and the difference has to be visible or the
            // whole thing turns into flattery.
            if !r.findings.notChecked.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Not checked")
                    .font(.headline)
                    .foregroundStyle(AppPalette.inkSoft)
                ForEach(r.findings.notChecked, id: \.self) { reason in
                    Text("· " + reason)
                        .font(.footnote)
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }

            // Against the player's own previous sessions of this kind. Same
            // floor as the bench card, same silence when nothing moved, same
            // refusal to say why.
            // Computed once by the recorder when the session stopped. The
            // first version reloaded every session file from disk inside
            // this body, on every re-render.
            if !r.trend.notes.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Against your last \(r.trend.baselineCount)")
                    .font(.headline)
                    .foregroundStyle(AppPalette.ink)
                ForEach(r.trend.notes, id: \.sentence) { note in
                    Text("· " + note.sentence)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.ink)
                }
            } else if let why = r.trend.notCompared {
                Text("No trend yet: " + why)
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .padding(.top, 4)
            }

            Text("Saved. Log today's match in the Journal and the coach reads this session with it.")
                .font(.footnote)
                .foregroundStyle(AppPalette.inkSoft)
                .padding(.top, 4)

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

    private func timeString(_ seconds: Double) -> String { SessionClock.string(seconds) }
}

/// A wrapping row of selectable chips.
///
/// Written rather than reached for because SwiftUI has no wrapping stack: a
/// LazyVGrid with adaptive columns is the standard substitute and gives every
/// option a fixed-width cell, which looks wrong when the labels run from
/// "Wall" to "Cross-court backhands". This measures nothing and simply lets
/// the chips flow, which is what the Home screen's row does.
private struct FlowChips: View {
    let kinds: [DrillContext.Kind]
    @Binding var selection: DrillContext.Kind
    let label: (DrillContext.Kind) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows(), id: \.first) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { kind in
                        Button { selection = kind } label: {
                            Text(label(kind))
                                .font(.subheadline.weight(selection == kind ? .semibold : .regular))
                                .foregroundStyle(selection == kind ? AppPalette.parchment : AppPalette.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(selection == kind ? AppPalette.clay : AppPalette.sand.opacity(0.5))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Two per row for the long labels, three for the short ones — decided by
    /// label length rather than by index, so a translation that lengthens
    /// "Wall" does not push a chip off the screen.
    private func rows() -> [[DrillContext.Kind]] {
        var out: [[DrillContext.Kind]] = []
        var row: [DrillContext.Kind] = []
        var width = 0
        for kind in kinds {
            let w = label(kind).count + 4
            if width + w > 34, !row.isEmpty { out.append(row); row = []; width = 0 }
            row.append(kind); width += w
        }
        if !row.isEmpty { out.append(row) }
        return out
    }
}
