import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var discussionStore: DiscussionStore

    private var dailyQuiz: Quiz {
        dailyQuizManager.todayQuiz
    }

    private var recommendedFlow: MobilityFlow {
        MobilityFlow.sampleFlows.first { $0.type == .quickReset } ?? MobilityFlow.sampleFlows[0]
    }

    private var featuredTrainingProgram: TrainingProgram {
        TrainingProgram.featuredProgram
    }

    private var featuredThread: DiscussionThread? {
        discussionStore.featuredThreads.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                dailyQuizCard
                trainingCard
                mobilityCard
                communityCard
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle("Today")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("CourtIQ")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.85))

            Text("Train the next point before you play it.")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(heroSubtitle)
                .foregroundStyle(.white.opacity(0.92))

            HStack(spacing: 12) {
                metricPill(title: "Streak", value: "\(dailyQuizManager.currentStreak) day")
                metricPill(title: "This Week", value: "\(dailyQuizManager.completedThisWeek)/7")
            }

            if dailyQuizManager.isCompletedToday {
                NavigationLink {
                    TrainingProgramDetailView(program: featuredTrainingProgram)
                } label: {
                    Text("Continue Today’s Training")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(AppPalette.ink)
            } else {
                NavigationLink {
                    QuizView(quiz: dailyQuiz) { summary in
                        dailyQuizManager.recordCompletion(summary: summary, isDaily: true)
                        session.updateCurrentFocus(summary.focusLabel)
                        session.updateTopMistakePatterns(summary.mistakeTypes)
                    }
                } label: {
                    Text("Continue Today’s Quiz")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(AppPalette.ink)
            }
        }
        .padding(24)
        .background(AppPalette.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var dailyQuizCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Daily IQ", subtitle: dailyQuizManager.isCompletedToday ? "Completed today" : "Ready for today")

            Text(dailyQuiz.focusLabel)
                .font(.title3.bold())

            Text("Five scenario-based questions built around \(dailyQuiz.primaryFocusTag ?? "match awareness").")
                .foregroundStyle(AppPalette.inkSoft)

            HStack(spacing: 12) {
                infoChip(systemImage: "checkmark.circle", text: "\(dailyQuiz.questions.count) questions")
                infoChip(systemImage: "target", text: dailyQuiz.primaryFocusTag ?? "court pattern")
            }

            NavigationLink {
                QuizView(quiz: dailyQuiz) { summary in
                    dailyQuizManager.recordCompletion(summary: summary, isDaily: true)
                    session.updateCurrentFocus(summary.focusLabel)
                    session.updateTopMistakePatterns(summary.mistakeTypes)
                }
            } label: {
                Text(dailyQuizManager.isCompletedToday ? "Review Today’s Quiz" : "Start Today’s Quiz")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var trainingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Today’s Training", subtitle: "8-week foundation")

            Text(featuredTrainingProgram.title)
                .font(.title3.bold())
            Text(featuredTrainingProgram.outcome)
                .foregroundStyle(AppPalette.inkSoft)

            HStack(spacing: 12) {
                infoChip(systemImage: "calendar", text: "\(featuredTrainingProgram.durationWeeks) weeks")
                infoChip(systemImage: "figure.run", text: "Gym + cardio")
            }

            NavigationLink {
                TrainingProgramDetailView(program: featuredTrainingProgram)
            } label: {
                Text("Open Training Calendar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var mobilityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Recommended Mobility", subtitle: recommendedFlow.type.title)

            Text(recommendedFlow.title)
                .font(.title3.bold())
            Text(recommendedFlow.goal)
                .foregroundStyle(AppPalette.inkSoft)

            HStack(spacing: 12) {
                infoChip(systemImage: "timer", text: recommendedFlow.duration)
                infoChip(systemImage: "figure.walk", text: recommendedFlow.focusLabel)
            }

            NavigationLink {
                MobilityFlowDetailView(flow: recommendedFlow)
            } label: {
                Text(session.isPremiumUnlocked ? "Open Mobility Flow" : "Preview Mobility Flow")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var communityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Active Community Thread", subtitle: session.canWriteCommunityComment ? "Commenting unlocked" : "Read-only preview")

            if let featuredThread {
                Text(featuredThread.title)
                    .font(.title3.bold())
                Text(featuredThread.subtitle)
                    .foregroundStyle(AppPalette.inkSoft)

                HStack(spacing: 12) {
                    infoChip(systemImage: "bubble.left.and.bubble.right", text: "\(discussionStore.commentCount(for: featuredThread.id)) comments")
                    infoChip(systemImage: "clock", text: featuredThread.lastActivityLabel)
                }

                NavigationLink {
                    CommunityFeedView()
                } label: {
                    Text("Open Community")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
            } else {
                Text("Threads will appear here once content-linked discussion is available.")
                    .foregroundStyle(AppPalette.inkSoft)
            }
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var heroSubtitle: String {
        if session.isGuest {
            return "Guest preview is active. Your IQ progress and training history are saved locally."
        }

        if session.isSignedInWithApple {
            return "\(session.displayName), your current improvement focus is \(session.currentImprovementFocus.lowercased())."
        }

        return "Start with a guest profile or Apple sign-in to track progress, unlock premium, and keep your tennis week together."
    }

    private func metricPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer()
        }
    }

    private func infoChip(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AppPalette.sand.opacity(0.55))
            .clipShape(Capsule())
    }
}
