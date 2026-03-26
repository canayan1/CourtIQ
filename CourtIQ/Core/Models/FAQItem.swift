import Foundation

struct FAQItem: Identifiable, Codable {
    let id: String
    let question: String
    let answer: String
    let category: FAQCategory
}

enum FAQCategory: String, Codable, CaseIterable {
    case rules = "Rules"
    case scoring = "Scoring"
    case equipment = "Equipment"
    case technique = "Technique"
    case etiquette = "Etiquette"

    var icon: String {
        switch self {
        case .rules: return "book.fill"
        case .scoring: return "number.circle.fill"
        case .equipment: return "tennisball.fill"
        case .technique: return "figure.tennis"
        case .etiquette: return "hand.raised.fill"
        }
    }
}
