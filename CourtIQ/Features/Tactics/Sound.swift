import AVFoundation
import Foundation

/// Rocco's sound set: nine short cartoon stings, bundled as WAVs.
///
/// The clips are **synthesised**, by `tools-synthesise-sfx.swift` at the repo
/// root — cartoon SFX are pitch sweeps, fast-decaying blips and little arpeggios,
/// so they can be generated from waveform maths. That keeps the app's rules
/// intact: no third-party asset, no licence question, no network, ~290KB total.
///
/// Deliberately not a voice. Rocco never speaks: a spoken interjection would have
/// to be recorded or generated per language, and a synthetic one tends to land in
/// the uncanny valley precisely because the character is stylised.
///
/// Mirrors `Haptics`: a `@MainActor` enum with prepared players, so the first
/// sting has no load latency and call sites stay one line.
@MainActor
enum Sound {
    /// Which sting to play. Raw values are the file names in `Resources/Audio`.
    enum Sting: String, CaseIterable {
        /// A right answer. Fires on every correct pick, so it is the shortest.
        case correct
        /// A wrong pick — the classic descending cartoon boing, kept soft because
        /// the player is already disappointed.
        case wrong
        /// A lesson finished. Melodic and warm, with no percussive attack — the
        /// opposite of `correct`, which is how the two stay distinguishable.
        case complete
        /// A chapter badge. The biggest sound in the app and the only one that
        /// opens with a racket-swing whoosh.
        case celebrate
        /// A new level. A high sparkle rather than a fanfare, so it reads as
        /// "something upgraded" and not "you won something".
        case levelUp
        /// A day-streak milestone.
        case streak
        /// Rocco offering a side quest — reads as a spoken question mark.
        case curious
        /// Stepping through the conversation: a quiet ball bounce. Fires five to
        /// eight times a lesson, so it sits under the reading.
        case tap
        /// Opening a lesson: a racket swing, so starting a lesson feels like
        /// starting a point.
        case swing
    }

    /// Stored as "muted" rather than "enabled" so that an absent key — a fresh
    /// install — means sound is on.
    static let mutedKey = "DropVolley.tactics.sound.muted"
    private static var players: [Sting: AVAudioPlayer] = [:]

    static var isEnabled: Bool {
        !UserDefaults.standard.bool(forKey: mutedKey)
    }

    /// Call once at launch, alongside `Haptics.warmUp()`.
    ///
    /// The session category is `.ambient`: these stings must mix with whatever the
    /// player already has playing rather than interrupting it, and must go silent
    /// when the Ring/Silent switch is off — an app that keeps pinging over
    /// someone's music on a court is an app they mute permanently.
    static func prepare() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        for sting in Sting.allCases {
            guard let url = Bundle.main.url(forResource: "tactics_" + sting.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[sting] = player
        }
    }

    static func play(_ sting: Sting) {
        guard isEnabled, let player = players[sting] else { return }
        // Restart rather than overlap: two answers can't be graded at once, and a
        // retapped sting overlapping itself sounds like a glitch.
        player.currentTime = 0
        player.play()
    }
}
