import Foundation
import SwiftUI
import CoreTransferable

/// The question bank, read from `clip_questions.json` — the same file the edge
/// functions and the web page mirror. Ids are what travels; labels are what
/// the player reads.
struct ClipQuestionBank: Decodable {
    struct Option: Decodable, Identifiable, Hashable { let id: String; let label: String }
    struct Q1: Decodable { let prompt: String; let options: [Option] }
    struct Q2: Decodable { let prompt: String; let byQ1: [String: [Option]] }
    struct Q3: Decodable { let prompt: String; let toleranceMs: Int }
    struct RatingSystem: Decodable {
        let label: String
        let min: Double?; let max: Double?; let step: Double?
        let values: [String]?; let hitWithin: Double; let lowerIsBetter: Bool?
    }
    struct Q4: Decodable { let prompt: String; let systems: [String: RatingSystem] }

    let version: Int
    let strokes: [String]
    let q1: Q1
    let q2: Q2
    let q3: Q3
    let q4: Q4
    let minVotesForCrowd: Int
    let maxClipMs: Int

    static let shared: ClipQuestionBank = {
        guard let url = Bundle.main.url(forResource: "clip_questions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let bank = try? JSONDecoder().decode(ClipQuestionBank.self, from: data)
        else { fatalError("clip_questions.json missing or malformed") }
        return bank
    }()

    func label(_ id: String) -> String {
        if let o = q1.options.first(where: { $0.id == id }) { return o.label }
        for list in q2.byQ1.values { if let o = list.first(where: { $0.id == id }) { return o.label } }
        return id
    }
}

/// A movie picked from Photos, received as a file so a 100 MB original never
/// sits in memory; `ClipsService.prepare` trims and shrinks it from disk.
struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("clips-in", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(UUID().uuidString + "." + (received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension))
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return PickedMovie(url: dest)
        }
    }
}

/// How the four kinds of view are named on screen, in one place.
enum ClipViewKind: String, CaseIterable {
    case coach, player, web, ai
    var icon: String { switch self { case .coach: "star.fill"; case .player: "person.2.fill"; case .web: "link"; case .ai: "sparkles" } }
    var titleKey: String { "clips.kind_\(rawValue)" }
}
