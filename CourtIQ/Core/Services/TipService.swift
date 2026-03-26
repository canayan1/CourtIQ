import Foundation
import FirebaseFirestore

final class TipService {
    private let db = Firestore.firestore()
    private let collection = "tips"

    func fetchTodayTip() async throws -> DailyTip {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let snapshot = try await db.collection(collection)
            .whereField("publishedDate", isGreaterThanOrEqualTo: Timestamp(date: today))
            .whereField("publishedDate", isLessThan: Timestamp(date: tomorrow))
            .whereField("isPremium", isEqualTo: false)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            throw AppError.noTipAvailable
        }
        return try doc.data(as: DailyTip.self)
    }

    func fetchTipArchive(limit: Int = 30) async throws -> [DailyTip] {
        let snapshot = try await db.collection(collection)
            .order(by: "publishedDate", descending: true)
            .limit(to: limit)
            .getDocuments()

        return try snapshot.documents.compactMap { try $0.data(as: DailyTip.self) }
    }
}
