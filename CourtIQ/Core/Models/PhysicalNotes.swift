import Foundation

/// Optional, self-reported physical constraints ("my knees complain", "bad
/// shoulder") the player can set ONCE in Profile. Every AI feature that sends
/// `PlayerContext` (swing analysis, match coaching) includes them so cues and
/// drills are adapted — e.g. no deep-knee-bend or jump-serve prescriptions for
/// a player who flagged knees.
///
/// Deliberately stored OUTSIDE the Tennis Profile model (own UserDefaults key)
/// so adding it can never break existing saved profiles, and it survives
/// profile re-takes.
enum PhysicalConstraint: String, CaseIterable, Codable, Identifiable {
    case knee
    case shoulder
    case lowerBack
    case hip
    case elbow
    case wrist

    var id: String { rawValue }

    func title(lang: AppLanguage) -> String {
        let tr = lang == .turkish
        switch self {
        case .knee:      return tr ? "Diz" : "Knee"
        case .shoulder:  return tr ? "Omuz" : "Shoulder"
        case .lowerBack: return tr ? "Bel" : "Lower back"
        case .hip:       return tr ? "Kalça" : "Hip"
        case .elbow:     return tr ? "Dirsek" : "Elbow"
        case .wrist:     return tr ? "El bileği" : "Wrist"
        }
    }

    /// English label used in the AI context line (grounding is EN regardless
    /// of UI language, matching `PlayerContext`'s convention).
    var contextLabel: String {
        switch self {
        case .knee:      return "knee"
        case .shoulder:  return "shoulder"
        case .lowerBack: return "lower back"
        case .hip:       return "hip"
        case .elbow:     return "elbow"
        case .wrist:     return "wrist"
        }
    }
}

enum PhysicalNotes {
    private static let key = "DropVolley.physicalNotes.v1"

    static var selection: Set<PhysicalConstraint> {
        get {
            guard let raw = UserDefaults.standard.array(forKey: key) as? [String] else { return [] }
            return Set(raw.compactMap(PhysicalConstraint.init(rawValue:)))
        }
        set {
            UserDefaults.standard.set(newValue.map(\.rawValue).sorted(), forKey: key)
        }
    }

    static func toggle(_ constraint: PhysicalConstraint) {
        var current = selection
        if current.contains(constraint) { current.remove(constraint) } else { current.insert(constraint) }
        selection = current
    }

    /// The line appended to `PlayerContext`. Kept SHORT (the context string is
    /// capped): the detailed adaptation rules live in the edge functions'
    /// system prompts, which key off the "PHYSICAL NOTES" marker. Nil when
    /// nothing is flagged (context unchanged).
    static func contextLine() -> String? {
        let picked = PhysicalConstraint.allCases.filter { selection.contains($0) }
        guard !picked.isEmpty else { return nil }
        let list = picked.map(\.contextLabel).joined(separator: ", ")
        return "PHYSICAL NOTES: \(list) — adapt cues/drills; no high-load prescriptions for these areas; prefer low-impact alternatives."
    }
}
