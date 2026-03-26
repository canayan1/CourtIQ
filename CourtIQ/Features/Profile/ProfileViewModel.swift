import Foundation
import Observation

@Observable
final class ProfileViewModel {
    var profile: UserProfile?
    var selectedSkillLevel: SkillLevel = .beginner
    var isLoading: Bool = false

    func loadProfile(authService: AuthService, userService: UserService) async {
        guard let uid = authService.currentUser?.uid else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            profile = try await userService.fetchProfile(uid: uid)
            selectedSkillLevel = profile?.skillLevel ?? .beginner
        } catch {
            profile = nil
        }
    }

    func signOut(using authService: AuthService) {
        try? authService.signOut()
    }
}
