import Foundation

enum Constants {
    enum Firestore {
        static let tips         = "tips"
        static let quizzes      = "quizzes"
        static let faq          = "faq"
        static let users        = "users"
        static let quizResults  = "quizResults"
    }

    enum Analytics {
        static let quizCompleted        = "quiz_completed"
        static let tipViewed            = "tip_viewed"
        static let premiumUpsellShown   = "premium_upsell_shown"
        static let subscriptionStarted  = "subscription_started"
    }
}
