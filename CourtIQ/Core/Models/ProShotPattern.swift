import Foundation
import CoreGraphics

/// One animated tactical pattern from a pro player. "Today's Pro Shot."
///
/// The pattern is a *sequence* of shots — typically 3-5 — each with the
/// ball's origin and landing point in normalized court space, plus the
/// new positions for YOU/OP after that shot is played. The animation
/// view interpolates the ball along a quadratic arc for each shot and
/// snaps the markers between shots.
///
/// Authored in `pro_shot_patterns.json`. Localized text fields follow the
/// existing `*Tr` optional-string convention.
struct ProShotPattern: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    var titleTr: String? = nil
    let playerName: String
    let tagline: String
    var taglineTr: String? = nil
    let surface: String                  // "clay" | "grass" | "hard"
    let shots: [ProShotEvent]

    func localizedTitle(for lang: AppLanguage) -> String {
        lang == .turkish ? (titleTr ?? title) : title
    }

    func localizedTagline(for lang: AppLanguage) -> String {
        lang == .turkish ? (taglineTr ?? tagline) : tagline
    }

    /// Convenience: the player position before the first shot (used to
    /// place markers at animation start).
    var initialYou: CGPoint {
        guard let first = shots.first else { return CGPoint(x: 0.5, y: 0.9) }
        return CGPoint(x: first.youX, y: first.youY)
    }

    var initialOp: CGPoint {
        guard let first = shots.first else { return CGPoint(x: 0.5, y: 0.1) }
        return CGPoint(x: first.opX, y: first.opY)
    }
}

/// One shot inside a pattern. The animation will:
///   1. Snap YOU/OP markers to the (youX/Y, opX/Y) configuration
///   2. Animate the ball from (fromX/Y) to (toX/Y) over `duration` seconds
///   3. Briefly hold, then advance to the next shot
///
/// `label` is the on-screen caption shown while this shot animates.
struct ProShotEvent: Codable, Hashable {
    let fromX: Double
    let fromY: Double
    let toX: Double
    let toY: Double
    let duration: Double                 // seconds, typical 0.7-1.0
    let youX: Double
    let youY: Double
    let opX: Double
    let opY: Double
    let label: String
    var labelTr: String? = nil

    func localizedLabel(for lang: AppLanguage) -> String {
        lang == .turkish ? (labelTr ?? label) : label
    }

    var from: CGPoint { CGPoint(x: fromX, y: fromY) }
    var to: CGPoint { CGPoint(x: toX, y: toY) }
    var you: CGPoint { CGPoint(x: youX, y: youY) }
    var op: CGPoint  { CGPoint(x: opX, y: opY) }
}

extension ProShotPattern {
    static let allPatterns: [ProShotPattern] = {
        let loaded = BundleContentLoader.loadArray([ProShotPattern].self,
                                                   named: "pro_shot_patterns")
        if !loaded.isEmpty { return loaded }
        return [fallbackPattern]
    }()

    /// Deterministic daily pick — day-of-epoch indexes into the catalog
    /// so every user sees the same pro pattern on the same day (Wordle
    /// social pattern).
    static func todaysPattern(for date: Date = Date()) -> ProShotPattern? {
        let all = allPatterns
        guard !all.isEmpty else { return nil }
        let dayIndex = Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970 / 86_400)
        return all[dayIndex % all.count]
    }

    static let fallbackPattern = ProShotPattern(
        id: "fallback_serve_plus_one",
        title: "Wide serve · open court",
        playerName: "",
        tagline: "Open the court, then hit through it.",
        surface: "hard",
        shots: [
            ProShotEvent(
                fromX: 0.50, fromY: 0.96, toX: 0.85, toY: 0.32,
                duration: 0.8,
                youX: 0.50, youY: 0.96, opX: 0.45, opY: 0.06,
                label: "1. Wide serve"
            ),
            ProShotEvent(
                fromX: 0.85, fromY: 0.32, toX: 0.45, toY: 0.86,
                duration: 0.7,
                youX: 0.50, youY: 0.90, opX: 0.85, opY: 0.12,
                label: "2. Defensive return"
            ),
            ProShotEvent(
                fromX: 0.45, fromY: 0.86, toX: 0.18, toY: 0.18,
                duration: 0.9,
                youX: 0.45, youY: 0.86, opX: 0.85, opY: 0.16,
                label: "3. Open court winner"
            ),
        ]
    )
}
