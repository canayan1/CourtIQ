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
    /// Optional so a new drill compiles before its translation lands; French
    /// falls back to English rather than showing nothing.
    var titleFr: String? = nil
    let focus: WallFocus
    let target: WallTarget
    /// Pacer cadence — beats (hits) per minute the rhythm ring pulses at.
    let tempoBPM: Int
    let difficulty: Int          // 1 = easy … 3 = hard
    let instruction: String
    let instructionTr: String
    var instructionFr: String? = nil
    /// IQ-oriented drills train the DECISION (placement / shot choice), not
    /// just the stroke — flagged so the hub can badge them for the IQ story.
    let isTennisIQ: Bool
    /// True when the drill's pattern (which stroke, which alternation) is
    /// something the phone cannot check — mic hears reps, camera reads height,
    /// neither knows a forehand from a backhand. The UI says so instead of
    /// letting a green seal overclaim. The Apple Watch (wrist IMU classifies
    /// strokes at ~98%) is the planned verifier.
    var patternOnHonour: Bool = false
    /// How the rep goal is graded. Continuous-rally drills demand the reps IN
    /// A ROW — the streak is the exercise. Sequence drills (feed, hit, fetch
    /// the ball, feed again) CANNOT hold a streak: the fetch is longer than
    /// the 3-second rally-gap rule, so a streak goal would be mathematically
    /// impossible and the rung forever red. Those grade TOTAL hits instead.
    var goalIsStreak: Bool = true

    func localizedTitle(for lang: AppLanguage) -> String {
        switch lang {
        case .turkish: return titleTr
        case .french:  return titleFr ?? title
        default:       return title
        }
    }
    func localizedInstruction(for lang: AppLanguage) -> String {
        switch lang {
        case .turkish: return instructionTr
        case .french:  return instructionFr ?? instruction
        default:       return instruction
        }
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

/// The player's self-rated level from onboarding, used to scale rep targets.
/// This is the player's OWN claim about their tennis, which is the honest
/// source — the in-app TennisPlayerLevel is derived from quiz activity and
/// says nothing about what their forehand can do.
enum WallPlayerBand {
    case beginner, club, advanced

    static var current: WallPlayerBand {
        switch UserDefaults.standard.string(forKey: "CourtIQ.onboardingLevel") {
        case "beginner":          return .beginner
        case "advanced", "coach": return .advanced
        default:                  return .club
        }
    }
}

extension WallDrill {
    /// The rep target this player actually faces. The authored numbers are
    /// club-level; a beginner gets ~70% and an advanced player ~130%, floored
    /// so no goal collapses below something worth doing. Seals already earned
    /// survive a level change — targets scale, history doesn't.
    var scaledReps: Int? {
        guard case .reps(let n) = target else { return nil }
        let factor: Double = switch WallPlayerBand.current {
        case .beginner: 0.7
        case .club:     1.0
        case .advanced: 1.3
        }
        return max(5, Int((Double(n) * factor).rounded()))
    }

    /// The curated starter library (v1). Ordered easy → hard-ish, mixing pure
    /// technique/consistency with the IQ-flagged decision drills.
    static let all: [WallDrill] = [
        WallDrill(
            id: "wall-steady",
            title: "Steady Rally", titleTr: "Sabit Ritim", titleFr: "Échange régulier",
            focus: .consistency, target: .reps(10), tempoBPM: 55, difficulty: 1,
            instruction: "Smooth, controlled shots to the SAME spot at the same height — grooving the rally ball.",
            instructionTr: "Aynı noktaya, aynı yükseklikte pürüzsüz ve kontrollü vuruşlar — ral topunu oturt.",
            instructionFr: "Des frappes fluides et contrôlées au MÊME endroit, à la même hauteur — tu installes ta balle d'échange.",
            isTennisIQ: false
        ),
        WallDrill(
            id: "wall-fh-bh",
            title: "Forehand ↔ Backhand", titleTr: "Forehand ↔ Backhand", titleFr: "Coup droit ↔ revers",
            focus: .movement, target: .reps(14), tempoBPM: 50, difficulty: 2,
            instruction: "Alternate a forehand then a backhand every shot; recover to the middle between each.",
            instructionTr: "Her vuruşta forehand-backhand değiştir; aralarda ortaya toparlan.",
            instructionFr: "Alterne coup droit puis revers à chaque frappe ; replace-toi au centre entre les deux.",
            isTennisIQ: false,
            patternOnHonour: true
        ),
        WallDrill(
            id: "wall-volley",
            title: "Quick-Hands Volley", titleTr: "Hızlı El Vole", titleFr: "Volées mains rapides",
            focus: .volley, target: .reps(20), tempoBPM: 96, difficulty: 2,
            instruction: "Stand close. Short, firm volleys — no backswing, punch and reset the racquet.",
            instructionTr: "Yakın dur. Kısa, sağlam voleler — geri sallama yok, vur ve raketi hazırla.",
            instructionFr: "Place-toi près du mur. Volées courtes et fermes — pas de préparation, tu pousses et tu remets la raquette devant.",
            isTennisIQ: false
        ),
        WallDrill(
            id: "wall-depth",
            title: "Depth Control: High ↔ Low", titleTr: "Derinlik: Yüksek ↔ Alçak", titleFr: "Contrôle de la profondeur : haut ↔ bas",
            focus: .iq, target: .reps(20), tempoBPM: 48, difficulty: 2,
            instruction: "Alternate a deep, high ball then a low skidding one — you choose the height on every shot.",
            instructionTr: "Derin-yüksek bir top, sonra alçak-kayan bir top — yüksekliği her vuruşta sen seç.",
            instructionFr: "Alterne une balle haute et profonde puis une balle basse qui glisse — c'est toi qui choisis la hauteur à chaque frappe.",
            isTennisIQ: true,
            patternOnHonour: true
        ),
        WallDrill(
            id: "wall-reset",
            // (goalIsStreak set below — slow arcs can't hold the 3s streak rule)
            title: "Reset Ball", titleTr: "Reset Topu", titleFr: "Balle de replacement",
            focus: .iq, target: .reps(12), tempoBPM: 40, difficulty: 2,
            instruction: "Under pressure, buy time: high, deep, slow 'reset' balls arced well above the net band.",
            instructionTr: "Baskı altında zaman kazan: file bandının çok üstünden, yüksek-derin-yavaş 'reset' topları.",
            instructionFr: "Sous pression, gagne du temps : des balles hautes, profondes et lentes, bien au-dessus de la bande du filet.",
            isTennisIQ: true,
            goalIsStreak: false
        ),
        WallDrill(
            id: "wall-first-strike",
            title: "First Strike (Serve +1)", titleTr: "İlk Vuruş (Servis +1)", titleFr: "Première frappe (service +1)",
            focus: .iq, target: .reps(15), tempoBPM: 44, difficulty: 3,
            instruction: "Feed hard, then play one aggressive first ball to the open side — pick the target BEFORE you hit.",
            instructionTr: "Sert besle, sonra boş tarafa tek agresif ilk top — hedefi vurmadan ÖNCE seç.",
            instructionFr: "Envoie fort, puis joue une première balle agressive dans l'espace libre — choisis la cible AVANT de frapper.",
            isTennisIQ: true,
            patternOnHonour: true,
            goalIsStreak: false
        ),
        WallDrill(
            id: "wall-approach",
            title: "Approach & Recover", titleTr: "Yaklaş & Toparlan", titleFr: "Monter et se replacer",
            focus: .movement, target: .reps(18), tempoBPM: 46, difficulty: 3,
            instruction: "Hit, step in toward the wall to touch the line, then backpedal to ready before the next ball.",
            instructionTr: "Vur, duvara doğru adımla çizgiye dokun, sonra bir sonraki toptan önce geri kaçıp hazırlan.",
            instructionFr: "Frappe, avance vers le mur pour toucher la ligne, puis recule en position d'attente avant la balle suivante.",
            isTennisIQ: false
        ),
        WallDrill(
            id: "wall-figure8",
            title: "Figure-8 Control", titleTr: "Sekiz Kontrolü", titleFr: "Contrôle en huit",
            focus: .technique, target: .reps(24), tempoBPM: 52, difficulty: 3,
            instruction: "Alternate inside-out then inside-in targets on the wall — tight, quiet racquet control.",
            instructionTr: "Duvarda sırayla inside-out ve inside-in hedefler — sıkı, sessiz raket kontrolü.",
            instructionFr: "Alterne les cibles décroisée puis intérieure sur le mur — une raquette précise et silencieuse.",
            isTennisIQ: false,
            patternOnHonour: true
        )
    ]
}
