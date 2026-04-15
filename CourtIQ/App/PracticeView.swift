import SwiftUI

struct PracticeView: View {
    @EnvironmentObject private var session: UserSessionManager
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                practiceHero

                VStack(alignment: .leading, spacing: 14) {
                    Text("Skill Blocks")
                        .font(.title3.bold())

                    ForEach(QuizCategory.allCases) { category in
                        if session.isPremiumUnlocked {
                            NavigationLink {
                                QuizView(quiz: Quiz.practiceQuiz(category: category)) {
                                    session.updateCurrentFocus(category.title)
                                    session.updateTopMistakePatterns($0.mistakeTypes)
                                }
                            } label: {
                                practiceCard(for: category, isLocked: false)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                practiceCard(for: category, isLocked: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Support Work")
                        .font(.title3.bold())

                    NavigationLink {
                        MobilityLibraryView()
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: "figure.walk")
                                .font(.title2)
                                .foregroundStyle(AppPalette.clay)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Mobility & Recovery Library")
                                    .font(.headline)
                                Text("Quick resets, daily mobility, and recovery flows built for tennis movement.")
                                    .foregroundStyle(AppPalette.inkSoft)
                            }

                            Spacer()
                        }
                        .padding()
                        .background(AppPalette.parchment)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(AppPalette.sand, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle("Practice")
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "Practice")
                    .environmentObject(session)
            }
        }
    }

    private var practiceHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deliberate reps")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.inkSoft)

            Text("Choose the pattern you want to sharpen, then run a focused block.")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Daily IQ stays free in Today. All Access unlocks the full library of repeatable skill blocks here.")
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func practiceCard(for category: QuizCategory, isLocked: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: category.systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(AppPalette.clay)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(category.title)
                        .font(.headline)
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                }
                Text(category.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
