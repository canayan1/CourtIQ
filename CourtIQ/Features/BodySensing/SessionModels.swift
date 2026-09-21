import Foundation

/// What the player said they were about to do.
///
/// Declaring the drill before starting is worth more than it looks. The wrist
/// cannot tell a cross-court forehand from a down-the-line one, and it cannot
/// see whether the ball went in — so a swing rate that falls halfway through a
/// session is ambiguous: tiring, or switching to a different shot? Saying
/// "twenty minutes of cross-court forehands" removes that degree of freedom,
/// and the coaching can then be about the thing that actually changed.
///
/// It is also the only honest way the app learns what a session WAS. Nothing
/// on the wrist distinguishes a match from a feeding drill.
struct DrillContext: Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case freePlay, crossCourtForehand, crossCourtBackhand, serve
        case volley, wall, match

        /// Whether every stroke in this drill should be the same wing. When it
        /// should, a change in the swing signature means something went wrong
        /// rather than that the player hit a different shot.
        var expectsOneWing: Bool {
            switch self {
            case .crossCourtForehand, .crossCourtBackhand, .serve: return true
            case .freePlay, .volley, .wall, .match: return false
            }
        }
    }

    var kind: Kind
}

extension DrillContext.Kind {
    /// What the microphone hears in this drill, and therefore what an
    /// unclaimed impact IS. Decided here, once, rather than by an `if onWall`
    /// in each recorder — the watch used to ignore the drill entirely and
    /// reported a wall's rebounds as an opponent's strokes.
    enum ContactModel { case twoPlayers, wallRebound, solo }

    var contactModel: ContactModel {
        switch self {
        case .wall: return .wallRebound
        case .serve: return .solo
        case .freePlay, .crossCourtForehand, .crossCourtBackhand, .volley, .match: return .twoPlayers
        }
    }

    /// The minimum gap between two impacts that are two strokes. A wall
    /// rally is one racket and one rebound per cycle; a rally between two
    /// people is faster. Read by the live tick and the final pass alike, so
    /// the number on the screen and the number in the file agree.
    var impactMinGap: Double {
        switch contactModel {
        case .wallRebound: return BallImpactAudio.wallMinGap
        case .twoPlayers, .solo: return BallImpactAudio.rallyMinGap
        }
    }
}

/// How often the watch talks to the phone, and why not more often.
///
/// A tick every twenty seconds is frequent enough that the phone screen is
/// never stale during a changeover, and rare enough that the radio stays
/// asleep between them. The messages are queued rather than live so that a
/// phone in a bag at the back of the court loses nothing: everything arrives
/// when it comes back in range, and the summary is sent again at the end so a
/// session survives even if every tick was dropped.
/// The rule for the microphone, which is not negotiable and belongs next to
/// the data rather than in a document nobody opens.
///
/// A session is recorded in a public place. The microphone will pick up the
/// people on the next court, the conversation behind the fence, and whatever
/// the player says between points. So audio is processed as it arrives and
/// discarded in the same breath: what survives a session is a list of instants
/// and how loud each one was — a few hundred numbers — and never a recording.
/// Nothing is written to disk, nothing is sent anywhere, and there is no
/// setting that turns that off.
///
/// On watchOS the microphone stays live in the background with a microphone
/// indicator on the watch face, which the player can tap to come straight back
/// to the app. That indicator is a feature, not a nuisance: somebody wearing a
/// live microphone around other people should be able to see that it is on.
enum AudioPolicy {
    /// Audio is reduced to this and nothing else is kept.
    typealias Kept = (t: Double, strength: Double)
    static let storesRecordings = false
    static let transmitsAudio = false
}

enum WatchSessionTransport {
    static let tickInterval: TimeInterval = 20
    /// The audio window the live tick detects on. Long enough that the
    /// adaptive threshold has a floor to measure against, short enough that a
    /// two-hour session does not copy and sort two hours of envelope every
    /// twenty seconds on the main actor — which is what the first version did.
    static let liveAudioWindow: TimeInterval = 90
}

/// Whether the sensing feature exists in this build. One flag, consulted by
/// every door — the Home route, the watch link, the recorder — so the feature
/// is gated once rather than half. Compile-time today; when it ships this
/// becomes a configuration or premium gate.
enum SensingFeature {
    #if DEBUG
    static let isEnabled = true
    #else
    static let isEnabled = false
    #endif
}

/// Small statistics both targets share, so the audio and the wrist detectors
/// cannot drift apart when one is retuned.
enum Stats {
    /// Middle value; the mean of the two middle values for an even count.
    static func median(_ xs: [Double]) -> Double {
        guard !xs.isEmpty else { return .nan }
        let s = xs.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }

    /// Adaptive threshold at median + k × MAD — the rule BallImpactAudio was
    /// calibrated on, and the one WristSwingDetector borrows.
    static func madThreshold(_ xs: [Double], k: Double) -> Double {
        let sorted = xs.sorted()
        let median = sorted[sorted.count / 2]
        let deviations = xs.map { abs($0 - median) }.sorted()
        let mad = max(deviations[deviations.count / 2], 1e-9)
        return median + k * mad
    }
}

/// m:ss, for a session clock on either screen.
enum SessionClock {
    static func string(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
