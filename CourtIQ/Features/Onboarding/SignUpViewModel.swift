import Foundation
import Observation

@Observable
final class SignUpViewModel {
    var displayName: String = ""
    var email: String = ""
    var password: String = ""
    var skillLevel: SkillLevel = .beginner
    var isLoading: Bool = false
    var showError: Bool = false
    var errorMessage: String = ""

    var isFormValid: Bool {
        !displayName.isEmpty && !email.isEmpty && password.count >= 6
    }

    func signUp(using authService: AuthService) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.signUp(email: email, password: password, displayName: displayName)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
