import SwiftUI

struct SignInView: View {
    @Environment(DIContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SignInViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "Email"), text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    SecureField(String(localized: "Password"), text: $viewModel.password)
                        .textContentType(.password)
                }
            }
            .navigationTitle(String(localized: "Sign In"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Sign In")) {
                        Task { await viewModel.signIn(using: container.authService) }
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
}
