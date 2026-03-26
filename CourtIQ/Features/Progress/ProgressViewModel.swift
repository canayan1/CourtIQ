import Foundation
import Observation

@Observable
final class ProgressViewModel {
    var recentResults: [QuizResult] = []
    var streakCount: Int = 0
    var isLoading: Bool = false

    func loadResults(
        progressService: ProgressService,
        authService: AuthService,
        premiumGate: PremiumGate
    ) async {
        guard let uid = authService.currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let all = try await progressService.fetchRemoteResults(uid: uid)
            let limit = premiumGate.isPremium ? all.count : premiumGate.freeProgressHistoryDays
            recentResults = Array(all.prefix(limit))
        } catch {
            recentResults = []
        }
    }
}
