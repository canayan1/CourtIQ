import SwiftUI

struct RootView: View {
    @Environment(DIContainer.self) private var container
    @State private var authService: AuthService?

    var body: some View {
        Group {
            if container.authService.isSignedIn {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .onAppear {
            authService = container.authService
        }
    }
}
