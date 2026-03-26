import Foundation
import FirebaseFirestore

final class FAQService {
    private let db = Firestore.firestore()
    private let collection = "faq"

    func fetchFAQ() async throws -> [FAQItem] {
        let snapshot = try await db.collection(collection)
            .order(by: "category")
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: FAQItem.self) }
    }
}
