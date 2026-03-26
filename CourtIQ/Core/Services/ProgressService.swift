import Foundation
import FirebaseFirestore

final class ProgressService {
    private let db = Firestore.firestore()

    func syncResults(_ results: [QuizResult], uid: String) async throws {
        let batch = db.batch()
        let ref = db.collection("users").document(uid).collection("quizResults")
        for result in results where !result.isSynced {
            let docRef = ref.document(result.id)
            try batch.setData(from: result, forDocument: docRef)
        }
        try await batch.commit()
    }

    func fetchRemoteResults(uid: String) async throws -> [QuizResult] {
        let snapshot = try await db.collection("users")
            .document(uid)
            .collection("quizResults")
            .order(by: "completedAt", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: QuizResult.self) }
    }
}
