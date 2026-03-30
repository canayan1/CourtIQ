import SwiftUI

struct ProfileView: View {
    @StateObject private var manager = DailyQuizManager.shared
    @EnvironmentObject private var session: UserSessionManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if session.isAuthenticated {
                    userCard
                } else {
                    signInCard
                }

                infoCard

                VStack(alignment: .leading, spacing: 16) {
                    Text("Mobility & Recovery")
                        .font(.headline)
                    Text("Browse premium tennis-specific mobility flows for rotation, shoulder freedom, hip mobility, and recovery.")
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        MobilityLibraryView()
                    } label: {
                        Text("Open mobility library")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                discussionCard
            }
            .padding()
        }
        .navigationTitle("Stats")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Performance")
                .font(.largeTitle.bold())
            Text("Your training journey is built around tennis decision-making and recovery.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var userCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hello, \(session.displayName)")
                        .font(.title2.bold())
                    Text(session.premiumStatus.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Sign out") {
                    session.signOut()
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Improvement focus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(session.currentImprovementFocus)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Top patterns")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(session.topMistakePatterns, id: \ .self) { pattern in
                    Text("• \(pattern)")
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sign in for a stronger profile")
                .font(.headline)
            Text("Create a profile to keep your training focus, premium status, and improvement notes ready for the next session.")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            Button(action: {
                session.signInWithApplePlaceholder()
            }) {
                HStack {
                    Image(systemName: "applelogo")
                    Text("Sign in with Apple")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button("Continue as guest") {
                session.signInAsGuest()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var infoCard: some View {
        VStack(spacing: 18) {
            statRow(label: "Current streak", value: "\(manager.currentStreak) days")
            statRow(label: "Quizzes completed", value: "\(manager.totalQuizzesCompleted)")
            statRow(label: "Today’s focus", value: session.currentImprovementFocus)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }

    private var discussionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discussion foundation")
                .font(.headline)
            Text("Discussion threads are ready to link to quiz items, training sessions, mobility flows, and premium insights.")
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }
            Spacer()
        }
    }
}
