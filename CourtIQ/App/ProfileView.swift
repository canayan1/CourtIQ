import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var trainingProgress: TrainingProgressManager

    @State private var showPaywall = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileHeader
                progressSection
                patternsSection
                historySection
                accountSection
                legalSection
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle("Profile")
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "Profile")
                    .environmentObject(session)
            }
        }
        .confirmationDialog("Delete account?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                Task {
                    isDeleting = true
                    await session.deleteAccount()
                    isDeleting = false
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears your profile, local history, training logs, and community activity on this device.")
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.displayName)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(session.premiumStatus.description)
                        .foregroundStyle(AppPalette.inkSoft)
                }

                Spacer()

                Circle()
                    .fill(AppPalette.sand.opacity(0.65))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: session.isSignedInWithApple ? "person.crop.circle.badge.checkmark" : "person.fill")
                            .font(.title2)
                            .foregroundStyle(AppPalette.clay)
                    )
            }

            HStack(spacing: 10) {
                statusChip(label: session.premiumStatus.title, accent: session.isPremiumUnlocked ? AppPalette.moss : AppPalette.clay)
                statusChip(label: session.isSignedInWithApple ? "Apple ID" : "Guest", accent: AppPalette.ink)
            }

            Text("Current focus: \(session.currentImprovementFocus)")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppPalette.sand.opacity(0.65))
                .clipShape(Capsule())
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Progress")
                .font(.title3.bold())

            HStack(spacing: 12) {
                statCard(title: "Daily Streak", value: "\(dailyQuizManager.currentStreak)", detail: "days")
                statCard(title: "Completed", value: "\(dailyQuizManager.totalQuizzesCompleted)", detail: "daily quizzes")
            }

            HStack(spacing: 12) {
                statCard(
                    title: "Training",
                    value: "\(trainingProgress.totalCompletedSessions(programID: TrainingProgram.featuredProgram.id))",
                    detail: "sessions logged"
                )
                statCard(
                    title: "Check-ins",
                    value: "\(trainingProgress.checkInHistory(programID: TrainingProgram.featuredProgram.id).count)",
                    detail: "weekly reviews"
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Weekly rhythm")
                        .font(.headline)
                    Spacer()
                    Text("\(dailyQuizManager.completedThisWeek)/7")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.inkSoft)
                }

                ProgressView(value: dailyQuizManager.weeklyCompletionRate)
                    .tint(AppPalette.clay)
            }
            .padding()
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Top Patterns To Clean Up")
                .font(.title3.bold())

            ForEach(dailyQuizManager.topMistakePatterns.isEmpty ? session.topMistakePatterns : dailyQuizManager.topMistakePatterns, id: \.self) { pattern in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "target")
                        .foregroundStyle(AppPalette.clay)
                    Text(pattern)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Archived Quiz History")
                    .font(.title3.bold())
                Spacer()
                if !session.isPremiumUnlocked {
                    Text("Premium")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppPalette.clay.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if session.isPremiumUnlocked {
                if dailyQuizManager.archivedDailyHistory.isEmpty {
                    Text("Complete your first daily quiz to build an archive.")
                        .foregroundStyle(AppPalette.inkSoft)
                } else {
                    ForEach(dailyQuizManager.archivedDailyHistory.prefix(5)) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.focusLabel)
                                    .font(.headline)
                                Text(record.completedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(AppPalette.inkSoft)
                            }
                            Spacer()
                            Text(record.accuracyText)
                                .font(.headline.monospacedDigit())
                        }
                        .padding()
                        .background(AppPalette.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppPalette.sand, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unlock the archive to review previous quiz sessions, track focus changes, and spot recurring decision errors.")
                        .foregroundStyle(AppPalette.inkSoft)
                    Button("Unlock All Access") {
                        showPaywall = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account")
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 12) {
                accountRow(label: "Mode", value: session.isSignedInWithApple ? "Sign in with Apple" : "Guest preview")
                accountRow(label: "Plan", value: session.premiumStatus.title)
                accountRow(label: "Billing", value: session.subscriptionManager.integrationMode.title)
                accountRow(label: "Integration", value: session.integrationSummary)
            }
            .padding()
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if !session.isSignedInWithApple {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Upgrade this profile with Sign in with Apple to unlock purchases, sync, and community posting.")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.inkSoft)

                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        session.handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                }
                .padding()
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }

            if !session.isPremiumUnlocked {
                Button("View All Access Plans") {
                    showPaywall = true
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Manage Subscription") {
                    session.openManageSubscriptions()
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Restore Purchases") {
                Task {
                    await session.restorePurchases()
                }
            }
            .buttonStyle(.bordered)

            Button(session.isGuest ? "Leave Guest Preview" : "Sign Out") {
                session.signOut()
            }
            .buttonStyle(.bordered)

            Button(isDeleting ? "Deleting..." : "Delete Account", role: .destructive) {
                showDeleteConfirmation = true
            }
            .buttonStyle(.bordered)
            .disabled(isDeleting)
        }
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Policies")
                .font(.title3.bold())

            ForEach(LegalDocument.allCases) { document in
                NavigationLink {
                    LegalDocumentView(document: document)
                } label: {
                    HStack {
                        Text(document.title)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(detail)
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func accountRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statusChip(label: String, accent: Color) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(accent.opacity(0.14))
            .clipShape(Capsule())
    }
}
