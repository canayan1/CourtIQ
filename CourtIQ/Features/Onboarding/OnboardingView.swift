import SwiftUI

struct OnboardingView: View {
    @State private var viewModel = OnboardingViewModel()
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "tennisball.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(CourtIQTheme.accent)

                VStack(spacing: 8) {
                    Text("CourtIQ")
                        .font(.largeTitle.bold())
                    Text(String(localized: "Elevate your tennis IQ"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button(String(localized: "Get Started")) {
                        showSignUp = true
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Button(String(localized: "I already have an account")) {
                        viewModel.showSignIn = true
                    }
                    .foregroundStyle(CourtIQTheme.accent)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $viewModel.showSignIn) {
                SignInView()
            }
        }
    }
}
