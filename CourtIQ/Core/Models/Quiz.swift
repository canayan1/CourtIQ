import Foundation

struct Quiz: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let difficulty: SkillLevel
    let questions: [QuizQuestion]
    let isPremium: Bool
    let category: TipCategory
}

struct QuizQuestion: Identifiable, Codable {
    let id: String
    let scenarioText: String
    let options: [QuizOption]
    let correctOptionID: String
    let explanation: String
    let isPremiumExplanation: Bool
}

struct QuizOption: Identifiable, Codable {
    let id: String
    let text: String
}
