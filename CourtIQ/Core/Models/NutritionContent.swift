import Foundation

// MARK: - Guide

/// The written guide and the "what should I eat today" picker text, decoded
/// from `nutrition_guide.<lang>.json`. English is the structural source; a
/// language file with the same shape replaces it wholesale, so a missing
/// translation falls back to the English guide rather than to blanks.
struct NutritionGuide: Codable {
    struct Source: Codable, Hashable {
        let label: String
        let url: String
    }

    struct Section: Codable, Identifiable, Hashable {
        let id: String
        let title: String
        let summary: String
        let body: [String]
        let keyPoints: [String]
        let sources: [Source]
    }

    /// The advice for one "hours until play" answer.
    struct TodayBase: Codable, Hashable {
        let headline: String
        let eat: String
        let avoid: String
        let why: String
    }

    struct Today: Codable {
        let base: [String: TodayBase]           // under1 · h1to2 · h2to4 · over4
        let intensity: [String: String]         // light · normal · hard
        let heat: [String: String]              // cool · warm · hot
        let lastSession: [String: String]       // flat · ok · great
    }

    let version: Int
    let sections: [Section]
    let today: Today
}

/// The four answers the picker asks for. Raw values are the JSON keys.
enum NutritionHoursUntil: String, CaseIterable, Identifiable {
    case under1, h1to2, h2to4, over4
    var id: String { rawValue }
    var labelKey: String { "nutrition.today_hours_\(rawValue)" }
}
enum NutritionIntensity: String, CaseIterable, Identifiable {
    case light, normal, hard
    var id: String { rawValue }
    var labelKey: String { "nutrition.today_intensity_\(rawValue)" }
}
enum NutritionHeat: String, CaseIterable, Identifiable {
    case cool, warm, hot
    var id: String { rawValue }
    var labelKey: String { "nutrition.today_heat_\(rawValue)" }
}
enum NutritionLastSession: String, CaseIterable, Identifiable {
    case flat, ok, great
    var id: String { rawValue }
    var labelKey: String { "nutrition.today_last_\(rawValue)" }
}

/// The composed answer: base advice plus one line per modifier. Composition
/// is the whole design — four answers, one card, no model in the loop.
struct NutritionTodayAdvice: Hashable {
    let headline: String
    let eat: String
    let avoid: String
    let why: String
    let extras: [String]
}

extension NutritionGuide {
    func advice(hours: NutritionHoursUntil, intensity: NutritionIntensity,
                heat: NutritionHeat, last: NutritionLastSession) -> NutritionTodayAdvice? {
        guard let base = today.base[hours.rawValue] else { return nil }
        let extras = [today.intensity[intensity.rawValue],
                      today.heat[heat.rawValue],
                      today.lastSession[last.rawValue]].compactMap { $0 }.filter { !$0.isEmpty }
        return NutritionTodayAdvice(headline: base.headline, eat: base.eat, avoid: base.avoid,
                                    why: base.why, extras: extras)
    }
}

// MARK: - Recipes

struct NutritionRecipeBook: Codable {
    struct QuizOption: Codable, Identifiable, Hashable {
        let id: String
        let label: String
        let tags: [String]
    }
    struct QuizQuestion: Codable, Identifiable, Hashable {
        let id: String
        let question: String
        let options: [QuizOption]
    }
    struct Ingredient: Codable, Hashable {
        let item: String
        let amount: String
    }
    struct Recipe: Codable, Identifiable, Hashable {
        let id: String
        let title: String
        let when: String
        let hoursBefore: String
        let prepMinutes: Int
        let tags: [String]
        let ingredients: [Ingredient]
        let steps: [String]
        let why: String
        let swap: String
    }

    let version: Int
    let quiz: [QuizQuestion]
    let recipes: [Recipe]

    /// +1 per shared tag, ties broken by prep time. Deterministic and
    /// explainable: the card can say "matches 3 of your answers".
    func ranked(for tags: Set<String>) -> [(recipe: Recipe, matches: Int)] {
        recipes
            .map { ($0, $0.tags.filter(tags.contains).count) }
            .sorted { a, b in a.1 != b.1 ? a.1 > b.1 : a.0.prepMinutes < b.0.prepMinutes }
    }
}

// MARK: - Loader

/// Reads the bundled content once per language. A language file that is
/// absent or fails to decode falls back to English; English absent means
/// the feature simply hides its guide and recipe cards.
enum NutritionContentStore {
    private static var guides: [String: NutritionGuide] = [:]
    private static var books: [String: NutritionRecipeBook] = [:]

    static func guide(for lang: AppLanguage) -> NutritionGuide? {
        load(&guides, name: "nutrition_guide", lang: lang)
    }

    static func recipes(for lang: AppLanguage) -> NutritionRecipeBook? {
        load(&books, name: "nutrition_recipes", lang: lang)
    }

    private static func load<T: Decodable>(_ cache: inout [String: T], name: String, lang: AppLanguage) -> T? {
        if let hit = cache[lang.rawValue] { return hit }
        for code in [lang.rawValue, "en"] {
            guard let url = Bundle.main.url(forResource: "\(name).\(code)", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(T.self, from: data) else { continue }
            cache[lang.rawValue] = decoded
            return decoded
        }
        return nil
    }
}
