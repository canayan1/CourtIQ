import Foundation

enum AppError: LocalizedError {
    case noTipAvailable
    case quizNotFound
    case profileNotFound
    case productNotFound
    case quizLimitReached
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .noTipAvailable:    return String(localized: "No tip available for today.")
        case .quizNotFound:      return String(localized: "Quiz not found.")
        case .profileNotFound:   return String(localized: "User profile not found.")
        case .productNotFound:   return String(localized: "Product not available.")
        case .quizLimitReached:  return String(localized: "Daily quiz limit reached. Upgrade to Premium for unlimited quizzes.")
        case .unknown(let e):    return e.localizedDescription
        }
    }
}
