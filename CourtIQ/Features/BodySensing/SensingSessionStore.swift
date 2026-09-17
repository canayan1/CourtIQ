import Foundation

/// One recorded session, from whichever device recorded it.
struct SensingSession: Codable, Identifiable, Equatable {
    var id: String
    var startedAt: Date
    var drill: String
    var highRateMotion: Bool
    var events: [SensorEventDTO]

    var decodedEvents: [SensorEvent] { events.compactMap(SensorEventCodec.event) }
}

/// Sessions on disk, one JSON file each under Documents/sensing.
///
/// This is the store the trends will be built on and the store the Journal
/// reads when a match is logged, so it is written to as batches arrive rather
/// than once at the end — a session whose phone died at the forty-minute mark
/// still has forty minutes on disk.
///
/// Same-device rule: what is stored is the event stream and never raw motion
/// or audio; the codec refuses raw motion and the microphone was reduced to
/// instants before anything reached here.
final class SensingSessionStore {
    static let shared = SensingSessionStore()

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sensing", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    private func url(_ id: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension("json")
    }

    func load(_ id: String) -> SensingSession? {
        guard let data = try? Data(contentsOf: url(id)) else { return nil }
        return try? decoder.decode(SensingSession.self, from: data)
    }

    /// Appends a batch, creating the session on first sight.
    @discardableResult
    func append(_ dtos: [SensorEventDTO], to id: String, startedAt: Date,
                drill: String, highRateMotion: Bool) -> SensingSession {
        var session = load(id) ?? SensingSession(id: id, startedAt: startedAt, drill: drill,
                                                 highRateMotion: highRateMotion, events: [])
        session.events.append(contentsOf: dtos)
        if let data = try? encoder.encode(session) { try? data.write(to: url(id), options: .atomic) }
        return session
    }

    func all() -> [SensingSession] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory,
                                                                        includingPropertiesForKeys: nil)
        else { return [] }
        return files.filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(SensingSession.self, from: Data(contentsOf: $0)) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// The session most plausibly belonging to a match logged for `date`:
    /// same calendar day, nearest start. Nil rather than a guess when the day
    /// has none, so a match without a recording gets no measured block.
    func nearest(to date: Date) -> SensingSession? {
        let cal = Calendar.current
        return all()
            .filter { cal.isDate($0.startedAt, inSameDayAs: date) }
            .min { abs($0.startedAt.timeIntervalSince(date)) < abs($1.startedAt.timeIntervalSince(date)) }
    }
}
