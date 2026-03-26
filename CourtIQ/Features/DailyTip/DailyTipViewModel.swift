import Foundation
import Observation

@Observable
final class DailyTipViewModel {
    var todayTip: DailyTip?
    var isLoading: Bool = false
    var errorMessage: String?

    func loadTodayTip(tipService: TipService) async {
        isLoading = true
        defer { isLoading = false }
        do {
            todayTip = try await tipService.fetchTodayTip()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
