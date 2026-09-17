import Combine
import Foundation
import SwiftUI
import WatchConnectivity

/// The phone's end of the wrist.
///
/// Receives event batches, stores them as they arrive, and keeps the live
/// match's stints and bench notes current so that opening the phone at the
/// changeover shows the games just played. It knows nothing about sensing —
/// the events it receives are the same vocabulary the phone's own recorder
/// speaks, so everything downstream of here is shared with the phone-only
/// path. That is the whole point of the codec.
///
/// UNRUN on the watch side; the receiving side has been compiled and not
/// exercised by a real link. Batches are handled identically whether they
/// arrive live (`didReceiveMessage`) or from the queue (`didReceiveUserInfo`),
/// and duplicates are harmless because the store is append-only and stints
/// are rebuilt from the whole stream each time.
@MainActor
final class WatchLink: NSObject, ObservableObject {
    static let shared = WatchLink()

    struct LiveMatch: Equatable {
        var id: String
        var drill: String
        var startedAt: Date
        var events: [SensorEvent]
        var stints: [Stint]
        var benchNotes: [BenchNote]
        var finished: Bool
    }

    @Published private(set) var live: LiveMatch?
    @Published private(set) var paired = false

    private let store = SensingSessionStore.shared

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated { session.activate() }
    }

    fileprivate func receive(_ payload: [String: Any]) {
        guard let id = payload["session"] as? String,
              let data = payload["events"] as? Data,
              let dtos = try? JSONDecoder().decode([SensorEventDTO].self, from: data)
        else { return }
        let drill = payload["drill"] as? String ?? DrillContext.Kind.freePlay.rawValue
        let started = Date(timeIntervalSince1970: payload["started"] as? Double
                           ?? Date().timeIntervalSince1970)
        let highRate = payload["highRate"] as? Bool ?? false
        let final = payload["final"] as? Bool ?? false

        let session = store.append(dtos, to: id, startedAt: started, drill: drill,
                                   highRateMotion: highRate)
        let events = session.decodedEvents
        let stints = StintBuilder.stints(from: events)
        let notes = stints.count >= 2
            ? BenchReport.compare(latest: stints[stints.count - 1], previous: stints[stints.count - 2])
            : []
        live = LiveMatch(id: id, drill: drill, startedAt: started, events: events,
                         stints: stints, benchNotes: notes, finished: final)
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in self.paired = session.isPaired && session.isWatchAppInstalled }
    }
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.receive(message) }
    }
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.receive(userInfo) }
    }
}

/// The card read on the bench.
///
/// Raw and specific: what changed between the stint just played and the one
/// before, in the player's own numbers, and nothing about why. The coaching
/// happens later, when the match is logged in the Journal and the AI Coach is
/// handed the whole session — during the match the player gets data.
struct BenchCardView: View {
    @ObservedObject private var link = WatchLink.shared

    var body: some View {
        if let m = link.live {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(m.finished ? "Session" : "Live from your watch")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                    Spacer()
                    Text("\(m.stints.count) stint\(m.stints.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                }
                if let last = m.stints.last {
                    HStack(spacing: 16) {
                        figure("You", "\(last.ownContacts)")
                        figure("Them", "\(last.opponentContacts)")
                        figure("Moves/min", String(format: "%.0f", last.effortsPerMinute))
                        if let r = last.readiness { figure("Ready", String(format: "%.0f%%", r * 100)) }
                        if let hr = last.meanHeartRate { figure("HR", String(format: "%.0f", hr)) }
                    }
                }
                if m.benchNotes.isEmpty {
                    Text(m.stints.count < 2
                         ? "After your first changeover this compares the games you just played with the ones before."
                         : "Nothing changed by more than 15% since the last stint.")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.inkSoft)
                } else {
                    ForEach(m.benchNotes, id: \.sentence) { note in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(note.change < 0 ? AppPalette.clay : AppPalette.moss)
                                .frame(width: 7, height: 7)
                                .padding(.top, 6)
                            Text(note.sentence)
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.ink)
                        }
                    }
                }
            }
            .padding(16)
            .background(AppPalette.parchment)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func figure(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(AppPalette.clay)
            Text(title).font(.caption2).foregroundStyle(AppPalette.inkSoft)
        }
    }
}
