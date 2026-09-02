import Foundation

// MARK: - Script

/// A scripted conversation with Rocco that teaches one lesson.
///
/// Scripts are a graph, not a list, because a wrong answer sends the player back
/// to the same question instead of forward — so nodes address each other by id.
struct DialogueScript: Codable, Identifiable, Hashable {
    let id: String
    /// The lesson this script teaches. Completing the script completes it.
    let lessonID: String
    let nodes: [DialogueNode]

    var first: DialogueNode? { nodes.first }

    func node(_ id: String) -> DialogueNode? {
        nodes.first { $0.id == id }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case lessonID = "lessonId"
        case nodes
    }
}

// MARK: - Node

struct DialogueNode: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        /// Rocco says one bubble, then the player taps Continue.
        case say
        /// A question. The player picks an option.
        case ask
        /// A bubble carrying a court diagram.
        case show
        /// Rocco offers a side training set.
        case offer
        /// The last node — reaching it completes the lesson.
        case finish
    }

    let id: String
    let kind: Kind
    var mood: Mood = .idle
    let text: String
    /// The next node. Nil on `finish`.
    var next: String? = nil
    /// Only on `ask`.
    var options: [Option] = []
    /// Only on `show`.
    var scene: CourtScene? = nil
    /// Only on `offer` — the side set to branch into.
    var setID: String? = nil

    struct Option: Codable, Hashable, Identifiable {
        /// What the player taps.
        let label: String
        let correct: Bool
        /// Rocco's immediate reaction to this choice.
        let reply: String
        /// Where this choice leads. For a wrong option this is the ask node's own
        /// id, which is what makes the retry loop work.
        let next: String

        var id: String { label }
    }

    // Explicit decoding: Swift's synthesized `Decodable` throws on a missing key
    // even when the property has a default, and most nodes omit most of these.
    private enum CodingKeys: String, CodingKey {
        case id, kind, mood, text, next, options, scene
        case setID = "setId"
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(Kind.self, forKey: .kind)
        mood = try c.decodeIfPresent(Mood.self, forKey: .mood) ?? .idle
        text = try c.decode(String.self, forKey: .text)
        next = try c.decodeIfPresent(String.self, forKey: .next)
        options = try c.decodeIfPresent([Option].self, forKey: .options) ?? []
        scene = try c.decodeIfPresent(CourtScene.self, forKey: .scene)
        setID = try c.decodeIfPresent(String.self, forKey: .setID)
    }

    init(id: String, kind: Kind, mood: Mood = .idle, text: String,
         next: String? = nil, options: [Option] = [],
         scene: CourtScene? = nil, setID: String? = nil) {
        self.id = id
        self.kind = kind
        self.mood = mood
        self.text = text
        self.next = next
        self.options = options
        self.scene = scene
        self.setID = setID
    }
}

// MARK: - Bundle file

/// The hand-authored script collection, `Resources/Content/dialogues.json`.
/// Lessons with no entry here are taught by a script derived at runtime — see
/// `DialogueBuilder` — so a lesson never has to wait for a writer.
struct DialogueBook: Codable {
    let version: Int
    let scripts: [DialogueScript]
}

// MARK: - Runtime transcript

/// One rendered bubble in the conversation. The view keeps an array of these and
/// appends as the player advances, which is what makes the screen read as a chat
/// history rather than a slideshow.
struct Bubble: Identifiable, Equatable {
    enum Speaker: Equatable {
        case rocco
        /// The player's own tapped answer, echoed back.
        case player
    }

    let id = UUID()
    let speaker: Speaker
    let text: String
    var scene: CourtScene? = nil
    /// Set on a player bubble so a wrong pick can be tinted.
    var wasWrong: Bool = false

    static func == (lhs: Bubble, rhs: Bubble) -> Bool { lhs.id == rhs.id }
}
