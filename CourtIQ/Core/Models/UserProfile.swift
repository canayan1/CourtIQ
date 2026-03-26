import Foundation
import SwiftData

@Model
final class UserProfile {
    var uid: String
    var displayName: String
    var email: String
    var avatarURL: String?
    var skillLevel: SkillLevel
    var joinDate: Date
    var isPremium: Bool
    var streakCount: Int
    var lastActiveDate: Date?

    init(
        uid: String,
        displayName: String,
        email: String,
        skillLevel: SkillLevel = .beginner,
        isPremium: Bool = false
    ) {
        self.uid = uid
        self.displayName = displayName
        self.email = email
        self.skillLevel = skillLevel
        self.joinDate = Date()
        self.isPremium = isPremium
        self.streakCount = 0
    }
}

enum SkillLevel: String, Codable, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case pro = "Pro"

    var description: String { rawValue }
}
