import Foundation
import Observation

@Observable
final class TipArchiveViewModel {
    var tips: [DailyTip] = []
    var isLoading: Bool = false

    func loadArchive(tipService: TipService) async {
        isLoading = true
        defer { isLoading = false }
        do {
            tips = try await tipService.fetchTipArchive()
        } catch {
            tips = []
        }
    }
}
