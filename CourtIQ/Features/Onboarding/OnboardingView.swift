import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject private var session: UserSessionManager
    @State private var selectedPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "Train the next point before you play it.",
            subtitle: "Daily IQ quizzes turn match decisions into repeatable habits.",
            systemImage: "brain.head.profile",
            accent: AppPalette.clay
        ),
        OnboardingPage(
            title: "Pair thinking with physical work.",
            subtitle: "Follow an 8-week tennis plan with weekly persistence checks and session logging.",
            systemImage: "figure.strengthtraining.traditional",
            accent: AppPalette.moss
        ),
        OnboardingPage(
            title: "Recover better and stay accountable.",
            subtitle: "Mobility flows, active discussion threads, and premium all-access support your full tennis week.",
            systemImage: "figure.cooldown",
            accent: AppPalette.ink
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            TabView(selection: $selectedPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    VStack(spacing: 24) {
                        ZStack {
                            Circle()
                                .fill(page.accent.opacity(0.16))
                                .frame(width: 180, height: 180)
                            Image(systemName: page.systemImage)
                                .font(.system(size: 72, weight: .semibold))
                                .foregroundStyle(page.accent)
                        }

                        VStack(spacing: 12) {
                            Text(page.title)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)

                            Text(page.subtitle)
                                .font(.title3)
                                .foregroundStyle(AppPalette.inkSoft)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .frame(maxHeight: 420)

            VStack(spacing: 14) {
                Button {
                    session.signInAsGuest()
                } label: {
                    Text("Continue as Guest")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)

                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    session.handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)

                Text("Guest mode keeps everything local. Sign in with Apple unlocks purchases, sync, and community posting.")
                    .font(.footnote)
                    .foregroundStyle(AppPalette.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 16)
        }
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                colors: [AppPalette.cream, AppPalette.parchment],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct OnboardingPage {
    let title: String
    let subtitle: String
    let systemImage: String
    let accent: Color
}
