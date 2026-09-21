import Foundation

/// One lesson's worth of the data that does not exist anywhere.
///
/// Stroke data exists in quantity. What nobody has is teaching data: this
/// player did X, the coach said Y, and two weeks later Z changed. This is one
/// row of it. Step 3 of docs/TEACHING-PLAN.md — the step only a coach can do,
/// which is why the record is thirty seconds of overhead and not five
/// minutes: the plan's most likely failure is that the rows stop coming.
struct LessonRecord: Codable, Identifiable, Equatable {
    var id: String
    /// A pseudonym the coach chooses. Never a name, never an email — the
    /// file that holds these must not be a list of who was taught.
    var student: String
    var stroke: String            // "forehand" for now; the taxonomy is per stroke
    var date: Date
    /// The lab capture before the cue (a file name under the lessons folder).
    var beforeClip: String?
    /// The ONE deviation the coach chose to address, by id from the taxonomy.
    /// One, so the effect is attributable.
    var deviationID: String
    /// The ONE cue given, by id from the cue library.
    var cueID: String
    /// The lab capture after the cue, same session.
    var afterClip: String?
    /// The lab capture at the next lesson — retention, not performance.
    var retentionClip: String?
    var retentionDate: Date?
    /// Anything the coach wants to remember. Free text, and therefore never
    /// aggregated — the ids are what aggregate.
    var note: String?
}

/// Consent, recorded before anything is filmed.
///
/// Students are filmed. A row without consent cannot exist; the store
/// refuses to create it. For a minor the consent is a parent's. This is
/// decided before the first capture, not after — the plan says so and the
/// code enforces it.
struct StudentConsent: Codable, Equatable {
    var student: String
    var grantedAt: Date
    var isMinor: Bool
    /// Who granted it, in the coach's words ("mother", "self").
    var grantedBy: String
    var withdrawnAt: Date?

    var isActive: Bool { withdrawnAt == nil }
}

/// Lesson rows and consents on disk, under Documents/lessons.
///
/// Everything stays on the coach's device. Nothing here syncs, and there is
/// no path that uploads a clip: the footage is of other people, and until
/// there is a reason and a policy it goes nowhere. Withdrawal deletes the
/// student's rows and clips, not just the consent.
final class LessonStore {
    static let shared = LessonStore()

    enum StoreError: Error, Equatable {
        case noConsent(String)
        case consentWithdrawn(String)
        case unknownDeviation(String)
        case unknownCue(String)
    }

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var consentsFile: URL { directory.appendingPathComponent("consents.json") }
    private var recordsFile: URL { directory.appendingPathComponent("lessons.json") }

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("lessons", isDirectory: true)
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Consent

    func consents() -> [StudentConsent] {
        guard let data = try? Data(contentsOf: consentsFile) else { return [] }
        return (try? decoder.decode([StudentConsent].self, from: data)) ?? []
    }

    func consent(for student: String) -> StudentConsent? {
        consents().first { $0.student == student }
    }

    func grantConsent(student: String, isMinor: Bool, grantedBy: String, at date: Date = Date()) {
        var all = consents().filter { $0.student != student }
        all.append(StudentConsent(student: student, grantedAt: date, isMinor: isMinor,
                                  grantedBy: grantedBy, withdrawnAt: nil))
        save(all, to: consentsFile)
    }

    /// Withdrawal is deletion. The rows and the clips go, not just the flag.
    func withdrawConsent(student: String, at date: Date = Date()) {
        var all = consents()
        if let i = all.firstIndex(where: { $0.student == student }) { all[i].withdrawnAt = date }
        save(all, to: consentsFile)
        let remaining = records().filter { $0.student != student }
        for r in records() where r.student == student {
            for clip in [r.beforeClip, r.afterClip, r.retentionClip].compactMap({ $0 }) {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(clip))
            }
        }
        save(remaining, to: recordsFile)
    }

    // MARK: - Records

    func records() -> [LessonRecord] {
        guard let data = try? Data(contentsOf: recordsFile) else { return [] }
        return (try? decoder.decode([LessonRecord].self, from: data)) ?? []
    }

    /// Adds a row. Refuses without active consent, and refuses ids that are
    /// not in the vocabularies — a free-text deviation would not aggregate,
    /// which is the whole reason the vocabularies exist.
    func add(_ record: LessonRecord,
             deviations: Set<String>, cues: Set<String>) throws {
        guard let c = consent(for: record.student) else { throw StoreError.noConsent(record.student) }
        guard c.isActive else { throw StoreError.consentWithdrawn(record.student) }
        guard deviations.contains(record.deviationID) else { throw StoreError.unknownDeviation(record.deviationID) }
        guard cues.contains(record.cueID) else { throw StoreError.unknownCue(record.cueID) }
        var all = records().filter { $0.id != record.id }
        all.append(record)
        save(all, to: recordsFile)
    }

    /// Attaches the retention capture to an existing row.
    func attachRetention(recordID: String, clip: String, at date: Date = Date()) {
        var all = records()
        guard let i = all.firstIndex(where: { $0.id == recordID }) else { return }
        all[i].retentionClip = clip
        all[i].retentionDate = date
        save(all, to: recordsFile)
    }

    /// The count that the plan's success depends on. Shown to the coach so
    /// they can watch it grow, which is the mitigation for the rows stopping.
    func triples() -> (started: Int, withAfter: Int, withRetention: Int) {
        let all = records()
        return (all.count, all.filter { $0.afterClip != nil }.count,
                all.filter { $0.retentionClip != nil }.count)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        if let data = try? encoder.encode(value) { try? data.write(to: url, options: .atomic) }
    }
}

/// The two vocabularies, loaded from the bundle. Drafts until the coach has
/// written them; the `draft` flag on the file says which.
struct TeachingVocabulary: Decodable {
    struct Deviation: Decodable, Identifiable { var id: String; var name: String; var description: String }
    struct Cue: Decodable, Identifiable { var id: String; var text: String; var targets: [String] }

    private struct DeviationFile: Decodable { var version: String; var deviations: [Deviation] }
    private struct CueFile: Decodable { var version: String; var cues: [Cue] }

    var deviations: [Deviation]
    var cues: [Cue]
    var version: String

    static func load(bundle: Bundle = .main) -> TeachingVocabulary? {
        guard let d = BundleContentLoader.load(DeviationFile.self, named: "teaching_deviations", bundle: bundle),
              let c = BundleContentLoader.load(CueFile.self, named: "teaching_cues", bundle: bundle)
        else { return nil }
        return TeachingVocabulary(deviations: d.deviations, cues: c.cues, version: d.version)
    }

    var deviationIDs: Set<String> { Set(deviations.map(\.id)) }
    var cueIDs: Set<String> { Set(cues.map(\.id)) }

    /// Cues that name this deviation as a target — the coach's own
    /// shortlist, in the app's words.
    func cues(for deviationID: String) -> [Cue] {
        cues.filter { $0.targets.contains(deviationID) }
    }
}
