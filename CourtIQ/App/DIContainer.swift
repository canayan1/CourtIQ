import Foundation
import Observation

@Observable
final class DIContainer {
    static let shared = DIContainer()

    let authService: AuthService
    let tipService: TipService
    let quizService: QuizService
    let faqService: FAQService
    let userService: UserService
    let progressService: ProgressService
    let premiumGate: PremiumGate

    private init() {
        self.authService = AuthService()
        self.tipService = TipService()
        self.quizService = QuizService()
        self.faqService = FAQService()
        self.userService = UserService()
        self.progressService = ProgressService()
        self.premiumGate = PremiumGate()
    }
}
