import SwiftUI

/// The wrist screen. Three states, one tap each.
///
/// Nobody reads this mid-point. What it has to get right is that starting is
/// one tap after picking the drill, that the changeover button is the biggest
/// thing on the screen because it is pressed with a sweaty thumb between
/// games, and that stopping is unmistakable. Everything else lives on the
/// phone.
struct WatchSessionView: View {
    @StateObject private var controller = WatchSessionController()
    @State private var drill: DrillContext.Kind = .match

    var body: some View {
        if controller.state == .running {
            running
        } else {
            setup
        }
    }

    private var setup: some View {
        ScrollView {
            VStack(spacing: 10) {
                Picker("Drill", selection: $drill) {
                    ForEach(DrillContext.Kind.allCases, id: \.self) { kind in
                        Text(label(for: kind)).tag(kind)
                    }
                }
                .frame(height: 70)
                if let failure = controller.failure {
                    Text(failure).font(.footnote).foregroundStyle(.red)
                }
                Button("Start") {
                    controller.start(drill: DrillContext(kind: drill, note: nil, plannedMinutes: nil))
                }
                .buttonStyle(.borderedProminent)
                Text("The microphone listens for ball contact and is never recorded.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var running: some View {
        VStack(spacing: 8) {
            Text(timeString(controller.elapsed))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
            HStack(spacing: 14) {
                stat("You", controller.strokes)
                stat("Them", controller.opponentStrokes)
                if let hr = controller.heartRate { stat("HR", Int(hr)) }
            }
            .font(.footnote)
            Button {
                controller.markChangeover()
            } label: {
                Text("Changeover")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            Button("Stop", role: .destructive) { controller.stop() }
                .buttonStyle(.bordered)
            if !controller.highRateMotion {
                Text("100 Hz fallback").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 6)
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 0) {
            Text("\(value)").font(.title3.weight(.semibold)).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func label(for kind: DrillContext.Kind) -> String {
        switch kind {
        case .freePlay: return "Free play"
        case .crossCourtForehand: return "X-court FH"
        case .crossCourtBackhand: return "X-court BH"
        case .serve: return "Serve"
        case .volley: return "Volley"
        case .wall: return "Wall"
        case .match: return "Match"
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
