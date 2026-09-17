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
    /// The player's own words, if they added any.
    var note: String?
    /// What they set out to do, in minutes. Nil for "until I stop".
    var plannedMinutes: Int?
}

/// A slice of the session, reported while it is still running.
///
/// Raw motion never leaves the sensor. 800 Hz across three axes is about 19 KB
/// every second before the gyroscope, which is both more than the link wants
/// and more than the battery will pay for — and the phone has no use for it,
/// because the detection that matters already ran on the watch. So the watch
/// sends what it concluded, not what it saw. A phone worn on the body has no
/// link to cross at all, but the same shape holds: detection runs as the data
/// arrives and only the conclusions are kept, so an hour's session is a few
/// kilobytes rather than a few hundred megabytes.
struct LiveTick: Codable, Equatable {
    /// Seconds since the session started.
    var elapsed: Double
    var swings: Int
    var swingsPerMinute: Double
    /// Median peak rotation rate over this slice, rad/s. Compared against the
    /// session's own opening minutes rather than any absolute figure, because
    /// what a hard swing measures differs by player, racket and where the
    /// watch sits on the wrist.
    var medianPeakRotation: Double
    var heartRate: Double?
    /// Metres covered, from HealthKit's workout distance, which fuses GPS with
    /// the accelerometer and is steadier than either alone.
    var distanceMetres: Double?

    /// Where the watch thinks it is, and how sure it is.
    ///
    /// The accuracy figure travels WITH the fix on purpose, because how much
    /// this is worth is a measurement rather than an opinion. The scales it
    /// has to beat: a singles court is 23.77 m by 8.23, baseline to service
    /// line is 5.49 m, and the camera pipeline resolves a foot to about 1 cm
    /// near the baseline.
    ///
    /// At the three to five metres a single-frequency receiver manages, none
    /// of those distinctions survive. The dual-frequency L1/L5 receiver in the
    /// Ultra is quoted nearer one to two metres under open sky, which is a
    /// different proposition: baseline versus net is a twelve-metre question
    /// and could hold up, and deuce side versus ad side might. Which of those
    /// is true on a real court in Dublin is something to find out from
    /// recorded fixes, not to decide here — so the fix is stored, its accuracy
    /// is stored beside it, and no feature quotes a position until the
    /// accuracy that came back says it can.
    var latitude: Double?
    var longitude: Double?
    /// Metres of horizontal uncertainty as reported by CoreLocation. Negative
    /// means the fix is invalid.
    var locationAccuracy: Double?
    /// Speed in m/s from the location fix, when it has one.
    var speed: Double?

    /// Whether a fix is good enough to say which END of the court somebody is
    /// at — a twelve-metre distinction, so it needs a few metres of accuracy
    /// rather than a few centimetres.
    var canPlaceOnCourtEnd: Bool {
        guard let a = locationAccuracy, a > 0 else { return false }
        return a <= 4
    }

    /// Whether a fix could separate the two halves of the court sideways.
    /// A doubles court is 10.97 m wide, so half of it is 5.5 — the fix has to
    /// be comfortably inside that to mean anything.
    var canPlaceOnCourtSide: Bool {
        guard let a = locationAccuracy, a > 0 else { return false }
        return a <= 2
    }
}

/// Everything the phone needs once the session ends.
struct WatchSessionSummary: Codable, Equatable {
    var id: UUID
    var startedAt: Date
    var duration: Double
    var drill: DrillContext
    var ticks: [LiveTick]

    var totalSwings: Int
    /// Rally length proxy: the median gap between consecutive strokes. In a
    /// drill it measures the feed's rhythm; in a match it measures how long
    /// the points were.
    var medianGapBetweenSwings: Double?
    var medianImpactG: Double?
    /// Whether the high-rate sensors were available. Older watches fall back
    /// to 100 Hz, which still counts strokes but places contact far less
    /// precisely — so anything quoted from a fallback session has to say so.
    var highRateMotion: Bool

    /// How far the swing faded, as a percentage of the opening quarter.
    /// Positive means the player was swinging harder at the end than at the
    /// start; negative is the usual direction.
    var intensityDriftPercent: Double? {
        let rotations = ticks.map(\.medianPeakRotation).filter { $0 > 0 }
        guard rotations.count >= 4 else { return nil }
        let quarter = max(1, rotations.count / 4)
        let opening = rotations.prefix(quarter).reduce(0, +) / Double(quarter)
        let closing = rotations.suffix(quarter).reduce(0, +) / Double(quarter)
        guard opening > 0 else { return nil }
        return (closing - opening) / opening * 100
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
    /// Ticks are accumulated and sent in batches of this many, so a session
    /// that runs for an hour costs about nine transfers rather than 180.
    static let ticksPerTransfer = 10
}
