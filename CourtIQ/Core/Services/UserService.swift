import Foundation
import FirebaseFirestore
import FirebaseAuth

final class UserService {
    private let db = Firestore.firestore()
    private let collection = "users"

    func fetchProfile(uid: String) async throws -> UserProfile {
        let doc = try await db.collection(collection).document(uid).getDocument()
        guard doc.exists else { throw AppError.profileNotFound }
        return try doc.data(as: UserProfile.self)
    }

    func createProfile(_ profile: UserProfile) async throws {
        try db.collection(collection).document(profile.uid).setData(from: profile)
    }

    func updateProfile(_ profile: UserProfile) async throws {
        try db.collection(collection).document(profile.uid).setData(from: profile, merge: true)
    }

    func updateSkillLevel(_ level: SkillLevel, uid: String) async throws {
        try await db.collection(collection).document(uid).updateData([
            "skillLevel": level.rawValue
        ])
    }
}
