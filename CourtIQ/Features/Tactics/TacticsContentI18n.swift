import Foundation

/// Translations for lesson CONTENT — the 30 lessons and Rocco's 270 dialogue
/// lines — kept in their own flat key/value file per language rather than as
/// `titleTr` / `titleFr` siblings inside `tactics_curriculum.json`.
///
/// The structural file stays the single source of truth for shape, ids,
/// diagrams and quiz indices, so a translation pass can never reorder an
/// option list or drop a diagram, and a key that is missing or empty falls
/// straight back to the English that shipped in the structure. That fallback
/// is what lets a language land chapter by chapter instead of all at once.
///
/// Keys are content paths, built by `TacticsCopy`:
///
///     chapter.<id>.title | .subtitle | .hook
///     lesson.<id>.title | .situation | .principle | .defaultAction | .commonMistake
///     lesson.<id>.adj.<n>.when | .then
///     lesson.<id>.advanced.heading | .body
///     lesson.<id>.quiz.scenario | .question | .opt.<n> | .explanation
///     dialogue.<scriptID>.<nodeID>
enum TacticsContentI18n {
    /// Parsed once per process, on first access. English is not a file: it is
    /// already in the curriculum, and asking for it returns an empty map so
    /// every lookup falls through to the structural value.
    private static let all: [String: [String: String]] = {
        var out: [String: [String: String]] = [:]
        for code in AppLanguage.shipped.map(\.rawValue) where code != "en" {
            guard let url = Bundle.main.url(forResource: "tactics_i18n.\(code)", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let map = try? JSONDecoder().decode([String: String].self, from: data)
            else { continue }
            out[code] = map
        }
        return out
    }()

    static func map(for lang: AppLanguage) -> [String: String] {
        all[lang.rawValue] ?? [:]
    }
}
