import Foundation
import Observation

@Observable
final class SignInViewModel {
    var email: String = ""
    var password: String = ""
    var isLoading: Bool = false
    var showError: Bool = false
    var errorMessage: String = ""

    var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }

    func signIn(using authService: AuthService) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
