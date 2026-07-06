import Foundation

/// One structured solo WALL-practice routine. The wall is the most available,
/// highest-rep practice partner there is; these drills turn "just hit against a
/// wall" into targeted work — consistency, technique, footwork, and a few that
/// train the Tennis-IQ decision (which ball to play), not just the stroke.
///
/// Content is hardcoded (a small curated set) rather than bundled JSON, so it
/// ships with the build with no pbxproj/resource churn. Each drill is reps- or
/// duration-targeted and carries a `tempoBPM` the session pacer uses to set a
/// rhythm (a racket "pock" per beat + a pulsing ring).
struct WallDrill: Identifiable, Hashable {
    let id: String
    let title: String
    let titleTr: String
    let focus: WallFocus
    let target: WallTarget
    /// Pacer cadence — beats (hits) per minute the rhythm ring pulses at.
    let tempoBPM: Int
    let difficulty: Int          // 1 = easy … 3 = hard
    let instruction: String
    let instructionTr: String
    /// IQ-oriented drills train the DECISION (placement / shot choice), not
    /// just the stroke — flagged so the hub can badge them for the IQ story.
    let isTennisIQ: Bool

    func localizedTitle(for lang: AppLanguage) -> String {
        lang == .turkish ? titleTr : title
    }
    func localizedInstruction(for lang: AppLanguage) -> String {
        lang == .turkish ? instructionTr : instruction
    }
}

/// What a drill primarily builds. The view maps these to colors/labels; the
/// model stays UI-free (just an SF Symbol name + localized label).
enum WallFocus: String, Hashable {
    case consistency, technique, volley, movement, iq

    var iconName: String {
        switch self {
        case .consistency: return "repeat"
        case .technique:   return "hand.raised.fingers.spread"
        case .volley:      return "bolt.fill"
        case .movement:    return "figure.run"
        case .iq:          return "brain.head.profile"
        }
    }

    func label(for lang: AppLanguage) -> String {
        switch (self, lang) {
        case (.consistency, .turkish): return "Tutarlılık"
        case (.consistency, _):        return "Consistency"
        case (.technique, .turkish):   return "Teknik"
        case (.technique, _):          return "Technique"
        case (.volley, .turkish):      return "Vole"
        case (.volley, _):             return "Volley"
        case (.movement, .turkish):    return "Ayak İşi"
        case (.movement, _):           return "Footwork"
        case (.iq, .turkish):          return "Tennis IQ"
        case (.iq, _):                 return "Tennis IQ"
        }
    }
}

/// A drill goal: either a rep count or a stopwatch duration. The session ends
/// (celebrates) when the target is met; the pacer paces the whole way.
enum WallTarget: Hashable {
    case reps(Int)
    case duration(seconds: Int)
}

extension WallDrill {
    /// The curated starter library (v1). Ordered easy → hard-ish, mixing pure
    /// technique/consistency with the IQ-flagged decision drills.
    static let all: [WallDrill] = [
        WallDrill(
            id: "wall-steady",
            title: "Steady Rally", titleTr: "Sabit Ritim",
            focus: .consistency, target: .reps(30), tempoBPM: 55, difficulty: 1,
            instruction: "Smooth, controlled shots to the SAME spot at the same height — grooving the rally ball.",
            instructionTr: "Aynı noktaya, aynı yükseklikte pürüzsüz ve kontrollü vuruşlar — ral topunu oturt.",
            isTennisIQ: false
        ),
        WallDrill(
            id: "wall-fh-bh",
            title: "Forehand ↔ Backhand", titleTr: "Forehand ↔ Backhand",
            focus: .movement, target: .reps(24), tempoBPM: 50, difficulty: 2,
            instruction: "Alternate a forehand then a backhand every shot; recover to the middle between each.",
            instructionTr: "Her vuruşta forehand-backhand değiştir; aralarda ortaya toparlan.",
            isTennisIQ: false
        ),
        WallDrill(
            id: "wall-volley",
            title: "Quick-Hands Volley", titleTr: "Hızlı El Vole",
            focus: .volley, target: .duration(seconds: 45), tempoBPM: 96, difficulty: 2,
            instruction: "Stand close. Short, firm volleys — no backswing, punch and reset the racquet.",
            instructionTr: "Yakın dur. Kısa, sağlam voleler — geri sallama yok, vur ve raketi hazırla.",
            isTennisIQ: false
        ),
        WallDrill(
            id: "wall-depth",
            title: "Depth Control: High ↔ Low", titleTr: "Derinlik: Yüksek ↔ Alçak",
            focus: .iq, target: .reps(20), tempoBPM: 48, difficulty: 2,
            instruction: "Alternate a deep, high ball then a low skidding one — you choose the height on every shot.",
            instructionTr: "Derin-yüksek bir top, sonra alçak-kayan bir top — yüksekliği her vuruşta sen seç.",
            isTennisIQ: true
        ),
        WallDrill(
            id: "wall-reset",
            title: "Reset Ball", titleTr: "Reset Topu",
            focus: .iq, target: .duration(seconds: 60), tempoBPM: 40, difficulty: 2,
            instruction: "Under pressure, buy time: high, deep, slow 'reset' balls arced well above the net band.",
            instructionTr: "Baskı altında zaman kazan: file bandının çok üstünden, yüksek-derin-yavaş 'reset' topları.",
            isTennisIQ: true
        ),
        WallDrill(
            id: "wall-first-strike",
            title: "First Strike (Serve +1)", titleTr: "İlk Vuruş (Servis +1)",
            focus: .iq, target: .reps(15), tempoBPM: 44, difficulty: 3,
            instruction: "Feed hard, then play one aggressive first ball to the open side — pick the target BEFORE you hit.",
            instructionTr: "Sert besle, sonra boş tarafa tek agresif ilk top — hedefi vurmadan ÖNCE seç.",
            isTennisIQ: true
        ),
        WallDrill(
            id: "wall-approach",
            title: "Approach & Recover", titleTr: "Yaklaş & Toparlan",
            focus: .movement, target: .reps(18), tempoBPM: 46, difficulty: 3,
            instruction: "Hit, step in toward the wall to touch the line, then backpedal to ready before the next ball.",
            instructionTr: "Vur, duvara doğru adımla çizgiye dokun, sonra bir sonraki toptan önce geri kaçıp hazırlan.",
            isTennisIQ: false
        ),
        WallDrill(
            id: "wall-figure8",
            title: "Figure-8 Control", titleTr: "Sekiz Kontrolü",
            focus: .technique, target: .reps(24), tempoBPM: 52, difficulty: 3,
            instruction: "Alternate inside-out then inside-in targets on the wall — tight, quiet racquet control.",
            instructionTr: "Duvarda sırayla inside-out ve inside-in hedefler — sıkı, sessiz raket kontrolü.",
            isTennisIQ: false
        )
    ]
}
