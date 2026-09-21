import Foundation

/// How a batch of events crosses the wrist-to-phone link.
///
/// Flat and small on purpose: a session is a few thousand of these, and
/// WatchConnectivity queues them through a link that may be a bag at the back
/// of the court for an hour. Three numbers and two short strings per event
/// keep an hour of tennis under a hundred kilobytes.
struct SensorEventDTO: Codable, Equatable {
    var k: String       // kind
    var t: Double
    var a: Double?
    var b: Double?
    var o: String?      // contact owner
}

/// The one boundary the audio policy and the motion policy are enforced at.
///
/// `.motion` is refused, not merely omitted. Raw samples never leave the
/// device that sensed them — that is a promise made in `SessionModels` and
/// `AudioPolicy`, and a codec that quietly serialised them would break it in a
/// place nobody would look. The detectors run where the data is; what travels
/// is what they concluded.
enum SensorEventCodec {

    enum CodecError: Error { case rawMotionRefused }

    static func dto(_ e: SensorEvent) throws -> SensorEventDTO {
        switch e {
        case .contact(let t, let s, let owner):
            let o: String
            switch owner { case .player: o = "p"; case .opponent: o = "o"; case .unknown: o = "u" }
            return SensorEventDTO(k: "c", t: t, a: s, b: nil, o: o)
        case .heartRate(let t, let bpm):   return SensorEventDTO(k: "h", t: t, a: bpm, b: nil, o: nil)
        case .changeover(let t):           return SensorEventDTO(k: "x", t: t, a: nil, b: nil, o: nil)
        case .splitStep(let t, let g):     return SensorEventDTO(k: "s", t: t, a: g, b: nil, o: nil)
        case .effort(let t, let peak):     return SensorEventDTO(k: "e", t: t, a: peak, b: nil, o: nil)
        case .activity(let t, let share):  return SensorEventDTO(k: "a", t: t, a: share, b: nil, o: nil)
        case .motion:                      throw CodecError.rawMotionRefused
        }
    }

    static func event(_ d: SensorEventDTO) -> SensorEvent? {
        switch d.k {
        case "c":
            let owner: SensorEvent.ContactOwner
            switch d.o { case "p": owner = .player; case "o": owner = .opponent; default: owner = .unknown }
            return .contact(t: d.t, strength: d.a ?? 0, owner: owner)
        case "h": return .heartRate(t: d.t, bpm: d.a ?? 0)
        case "x": return .changeover(t: d.t)
        case "s": return .splitStep(t: d.t, landingG: d.a ?? 0)
        case "e": return .effort(t: d.t, peakPush: d.a ?? 0)
        case "a": return .activity(t: d.t, movingShare: d.a ?? 0)
        default:  return nil
        }
    }

    /// Encodes everything that may travel. Raw motion in the input is a
    /// programming error upstream and is thrown, not dropped.
    static func encode(_ events: [SensorEvent]) throws -> Data {
        try JSONEncoder().encode(events.map(dto))
    }

    static func decode(_ data: Data) throws -> [SensorEvent] {
        try JSONDecoder().decode([SensorEventDTO].self, from: data).compactMap(event)
    }
}

/// One batch on the wire, and one shape for it on both sides.
///
/// The first version sent a hand-built dictionary with six magic keys and
/// parsed it by hand on the phone; a typo on either side dropped the whole
/// session into a silent `guard … else { return }`. This is typed, versioned,
/// and the only thing either side encodes or decodes.
struct SessionBatch: Codable, Equatable {
    static let currentVersion = 1
    var version: Int = SessionBatch.currentVersion
    var id: String
    var drill: String
    var startedAt: Date
    var highRateMotion: Bool
    var events: [SensorEventDTO]
    var final: Bool
}

extension SensorEventCodec {
    private static var coder: (JSONEncoder, JSONDecoder) {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return (e, d)
    }
    static func encode(_ batch: SessionBatch) throws -> Data { try coder.0.encode(batch) }
    static func decodeBatch(_ data: Data) throws -> SessionBatch { try coder.1.decode(SessionBatch.self, from: data) }
}
