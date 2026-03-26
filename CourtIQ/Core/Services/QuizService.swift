import Foundation
import FirebaseFirestore

final class QuizService {
    private let db = Firestore.firestore()
    private let collection = "quizzes"

    func fetchQuizzes(for skillLevel: SkillLevel? = nil) async throws -> [Quiz] {
        var query: Query = db.collection(collection)
        if let level = skillLevel {
            query = query.whereField("difficulty", isEqualTo: level.rawValue)
        }
        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Quiz.self) }
    }

    func fetchQuiz(id: String) async throws -> Quiz {
        let doc = try await db.collection(collection).document(id).getDocument()
        guard doc.exists else { throw AppError.quizNotFound }
        return try doc.data(as: Quiz.self)
    }
}
