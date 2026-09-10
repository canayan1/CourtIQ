import SwiftUI

// MARK: - Curriculum

/// The whole course, decoded once from `Resources/Content/curriculum.json`.
/// There is no backend: content ships with the binary, so every lesson works
/// offline and a content change is an app update.
struct Curriculum: Codable {
    let version: Int
    let chapters: [Chapter]
    /// Focused mini-courses that sit off the main path. Rocco offers one when a
    /// dialogue finds a specific gap ("do you know where your partner is about to
    /// serve?"), so they are entered from a conversation rather than from the rail
    /// alone.
    var sideSets: [Chapter] = []

    /// Flat lesson list in main-course order — the order the path walks. Side-set
    /// lessons are deliberately excluded: they must not shift the sequential
    /// unlock of the main course.
    var allLessons: [Lesson] { chapters.flatMap(\.lessons) }

    /// Every unit a lesson could live in, main chapters and side sets alike.
    var allUnits: [Chapter] { chapters + sideSets }

    func chapter(containing lessonID: String) -> Chapter? {
        allUnits.first { $0.lessons.contains { $0.id == lessonID } }
    }

    init(version: Int, chapters: [Chapter], sideSets: [Chapter] = []) {
        self.version = version
        self.chapters = chapters
        self.sideSets = sideSets
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        chapters = try c.decode([Chapter].self, forKey: .chapters)
        sideSets = try c.decodeIfPresent([Chapter].self, forKey: .sideSets) ?? []
    }
}

// MARK: - Chapter

/// A unit of lessons. Main chapters and side sets share this type: they differ
/// only in `isSideSet`, which decides whether they appear on the rail and whether
/// the sequential unlock runs across the whole course or just within the unit.
struct Chapter: Codable, Identifiable, Hashable {
    let id: String
    /// 1-based, used for the "CHAPTER 3" eyebrow. 0 for side sets.
    let number: Int
    let title: String
    /// One line telling the beginner what they'll be able to do afterwards.
    let subtitle: String
    /// SF Symbol name for the chapter marker.
    let symbol: String
    /// Chapter 1 is fully free — the freemium entry. Everything else is gated.
    let isFree: Bool
    let lessons: [Lesson]
    /// Side sets only: Rocco's one-line question that makes the gap feel real.
    var hook: String? = nil
    var isSideSet: Bool = false

    static func == (lhs: Chapter, rhs: Chapter) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(id: String, number: Int, title: String, subtitle: String, symbol: String,
         isFree: Bool, lessons: [Lesson], hook: String? = nil, isSideSet: Bool = false) {
        self.id = id; self.number = number; self.title = title; self.subtitle = subtitle
        self.symbol = symbol; self.isFree = isFree; self.lessons = lessons
        self.hook = hook; self.isSideSet = isSideSet
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        number = try c.decodeIfPresent(Int.self, forKey: .number) ?? 0
        title = try c.decode(String.self, forKey: .title)
        subtitle = try c.decode(String.self, forKey: .subtitle)
        symbol = try c.decode(String.self, forKey: .symbol)
        isFree = try c.decodeIfPresent(Bool.self, forKey: .isFree) ?? false
        lessons = try c.decode([Lesson].self, forKey: .lessons)
        hook = try c.decodeIfPresent(String.self, forKey: .hook)
        isSideSet = try c.decodeIfPresent(Bool.self, forKey: .isSideSet) ?? false
    }
}

// MARK: - Lesson

struct Lesson: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    /// The five-part teaching scheme every lesson follows, in render order:
    /// situation → principle → defaultAction → adjustments → commonMistake.
    ///
    /// The load-bearing rule of the scheme: `defaultAction` is what the player
    /// does RIGHT NOW, ALONE, with incomplete information. It may never depend
    /// on a partner, a signal, or an advance agreement — communication is only
    /// ever an adjustment or a side note. A test enforces this.

    /// The match moment, stated with what the player does NOT yet know.
    let situation: String
    /// The transferable rule. Shown big; if a player reads nothing else, this
    /// is the takeaway.
    let principle: String
    /// What to do now, alone, under uncertainty. Concrete and executable.
    let defaultAction: String
    /// 2–4 conditioned variants: opponent / partner / score / conditions.
    let adjustments: [Adjustment]
    /// The error this lesson exists to kill.
    let commonMistake: String
    /// The court picture. Optional so a purely conceptual lesson can skip it.
    let diagram: CourtScene?
    /// One scenario question. Answering it is what completes the lesson.
    let quiz: QuizItem

    /// The optional higher-level note: why the beginner rule is a default and not
    /// a law, and what a stronger player does instead. Absent on most lessons.
    /// This is the seam for a future "Advanced" track sold to intermediate-and-up
    /// players — deliberately additive, so beginners can ignore it and the
    /// beginner rule itself stays clean and confident. Optional, so it decodes as
    /// nil when the key is missing: Swift only auto-uses `decodeIfPresent` for
    /// Optionals, which is why this one field needs no custom `init(from:)`.
    let advanced: AdvancedNote?

    static func == (lhs: Lesson, rhs: Lesson) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// One conditioned variant of a lesson's default action.
struct Adjustment: Codable, Hashable {
    /// The condition, on one axis: opponent, partner, score, or conditions.
    let when: String
    /// The changed action.
    let then: String
}

/// A "Going further" note: the exception to the beginner rule, and the
/// higher-level play. Shown as an extra; never required to complete a lesson.
struct AdvancedNote: Codable, Hashable {
    let heading: String
    let body: String
}

// MARK: - Quiz

struct QuizItem: Codable, Hashable {
    /// The match situation, in plain language.
    let scenario: String
    let question: String
    let options: [String]
    let correctIndex: Int
    /// Why the right answer is right — shown after answering, always.
    let explanation: String
    /// Optional picture of the situation being asked about.
    let diagram: CourtScene?
}

// MARK: - Court scene (diagram spec)

/// A declarative court picture. Coordinates are normalized inside the doubles
/// court rectangle: `x` 0 (left sideline) → 1 (right sideline), `y` 0 (the
/// opponent's baseline, top) → 1 (your baseline, bottom). The net sits at
/// `y == 0.5`.
/// Note on decoding: Swift's synthesized `Decodable` throws on a missing key
/// even when the property has a default value, so every type here that a scene
/// may omit decodes explicitly with `decodeIfPresent`. That keeps the JSON terse
/// — a scene with only zones lists only zones.
struct CourtScene: Codable, Hashable {
    var zones: [Zone] = []
    var arrows: [Arrow] = []
    var players: [Marker] = []
    var balls: [Ball] = []
    /// One line under the picture explaining what to look at.
    var caption: String? = nil

    init(zones: [Zone] = [], arrows: [Arrow] = [], players: [Marker] = [],
         balls: [Ball] = [], caption: String? = nil) {
        self.zones = zones
        self.arrows = arrows
        self.players = players
        self.balls = balls
        self.caption = caption
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        zones = try c.decodeIfPresent([Zone].self, forKey: .zones) ?? []
        arrows = try c.decodeIfPresent([Arrow].self, forKey: .arrows) ?? []
        players = try c.decodeIfPresent([Marker].self, forKey: .players) ?? []
        balls = try c.decodeIfPresent([Ball].self, forKey: .balls) ?? []
        caption = try c.decodeIfPresent(String.self, forKey: .caption)
    }

    struct Point: Codable, Hashable {
        let x: Double
        let y: Double

        init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    /// A highlighted area of the court — a target, or a hole to avoid.
    struct Zone: Codable, Hashable {
        let x: Double
        let y: Double
        let w: Double
        let h: Double
        var tone: Tone = .good
        var label: String? = nil

        init(x: Double, y: Double, w: Double, h: Double,
             tone: Tone = .good, label: String? = nil) {
            self.x = x
            self.y = y
            self.w = w
            self.h = h
            self.tone = tone
            self.label = label
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            x = try c.decode(Double.self, forKey: .x)
            y = try c.decode(Double.self, forKey: .y)
            w = try c.decode(Double.self, forKey: .w)
            h = try c.decode(Double.self, forKey: .h)
            tone = try c.decodeIfPresent(Tone.self, forKey: .tone) ?? .good
            label = try c.decodeIfPresent(String.self, forKey: .label)
        }
    }

    /// A shot or a movement path.
    struct Arrow: Codable, Hashable {
        let from: Point
        let to: Point
        var kind: Kind = .shot
        var tone: Tone = .neutral
        var label: String? = nil

        enum Kind: String, Codable {
            /// Solid line — the ball's flight.
            case shot
            /// Dashed line — a player moving.
            case move
        }

        init(from: Point, to: Point, kind: Kind = .shot,
             tone: Tone = .neutral, label: String? = nil) {
            self.from = from
            self.to = to
            self.kind = kind
            self.tone = tone
            self.label = label
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.from = try c.decode(Point.self, forKey: .from)
            self.to = try c.decode(Point.self, forKey: .to)
            kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .shot
            tone = try c.decodeIfPresent(Tone.self, forKey: .tone) ?? .neutral
            label = try c.decodeIfPresent(String.self, forKey: .label)
        }
    }

    /// A player position. `role` decides the color and default label.
    struct Marker: Codable, Hashable {
        let x: Double
        let y: Double
        var role: Role = .you
        var label: String? = nil

        enum Role: String, Codable {
            case you, opponent, partner
        }

        init(x: Double, y: Double, role: Role = .you, label: String? = nil) {
            self.x = x
            self.y = y
            self.role = role
            self.label = label
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            x = try c.decode(Double.self, forKey: .x)
            y = try c.decode(Double.self, forKey: .y)
            role = try c.decodeIfPresent(Role.self, forKey: .role) ?? .you
            label = try c.decodeIfPresent(String.self, forKey: .label)
        }
    }

    struct Ball: Codable, Hashable {
        let x: Double
        let y: Double
        var label: String? = nil

        init(x: Double, y: Double, label: String? = nil) {
            self.x = x
            self.y = y
            self.label = label
        }

        init(from decoder: any Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            x = try c.decode(Double.self, forKey: .x)
            y = try c.decode(Double.self, forKey: .y)
            label = try c.decodeIfPresent(String.self, forKey: .label)
        }
    }

    /// Shared semantic coloring for zones and arrows.
    enum Tone: String, Codable {
        case good, bad, neutral, focus

        var color: Color {
            switch self {
            case .good:    return AppPalette.Court.good
            case .bad:     return AppPalette.Court.bad
            case .neutral: return AppPalette.Court.line
            case .focus:   return AppPalette.Court.focus
            }
        }
    }
}
