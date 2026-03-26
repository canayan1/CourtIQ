import SwiftUI

struct SignUpView: View {
    @Environment(DIContainer.self) private var container
    @State private var viewModel = SignUpViewModel()

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Display Name"), text: $viewModel.displayName)
                    .textContentType(.name)
                TextField(String(localized: "Email"), text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                SecureField(String(localized: "Password"), text: $viewModel.password)
                    .textContentType(.newPassword)
            }

            Section {
                Picker(String(localized: "Skill Level"), selection: $viewModel.skillLevel) {
                    ForEach(SkillLevel.allCases, id: \.self) { level in
                        Text(level.description).tag(level)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Create Account"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Sign Up")) {
                    Task { await viewModel.signUp(using: container.authService) }
                }
                .disabled(viewModel.isLoading || !viewModel.isFormValid)
            }
        }
        .alert(String(localized: "Error"), isPresented: $viewModel.showError) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}
