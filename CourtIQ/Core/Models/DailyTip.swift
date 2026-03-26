import Foundation
import SwiftData

@Model
final class DailyTip {
    var id: String
    var title: String
    var body: String
    var category: TipCategory
    var publishedDate: Date
    var isPremium: Bool
    var isRead: Bool

    init(
        id: String,
        title: String,
        body: String,
        category: TipCategory,
        publishedDate: Date,
        isPremium: Bool = false
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.category = category
        self.publishedDate = publishedDate
        self.isPremium = isPremium
        self.isRead = false
    }
}

enum TipCategory: String, Codable, CaseIterable {
    case technique = "Technique"
    case tactics = "Tactics"
    case fitness = "Fitness"
    case mental = "Mental Game"

    var icon: String {
        switch self {
        case .technique: return "figure.tennis"
        case .tactics: return "brain.head.profile"
        case .fitness: return "heart.fill"
        case .mental: return "sparkles"
        }
    }
}
