import SwiftUI

struct TrainingHubView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var trainingProgress: TrainingProgressManager

    private let programs = TrainingProgram.allPrograms

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                featuredCard
                premiumTracks
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle("Training")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Performance engine")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.inkSoft)

            Text("Build the body behind better tennis decisions.")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Start with the free 8-week hybrid plan, then unlock deeper tracks for footwork, shot power, flexibility, and match conditioning.")
                .foregroundStyle(AppPalette.inkSoft)

            HStack(spacing: 12) {
                chip(text: "8-week cycle", systemImage: "calendar")
                chip(text: "Persistence checks", systemImage: "chart.line.uptrend.xyaxis")
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

    private var featuredCard: some View {
        let program = TrainingProgram.featuredProgram

        return VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Free Foundation", subtitle: "Start here")

            Text(program.title)
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 6) {
                Text("PHEC Program")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.white)
                Text("Plyometrics, hypertrophy, explosiveness, conditioning")
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.white.opacity(0.88))
            }

            Text("Repeat the weekly structure for 8 weeks, log each session, and compare your persistence checks over time.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.9))

            NavigationLink {
                TrainingProgramDetailView(program: program)
            } label: {
                Text("Open 8-Week Plan")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(
            AppPalette.trainingGradient
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var premiumTracks: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Premium Tracks", subtitle: session.isPremiumUnlocked ? "Unlocked" : "Locked")

            ForEach(programs.filter(\.isPremium)) { program in
                NavigationLink {
                    TrainingProgramDetailView(program: program)
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: program.category.symbolName)
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(session.isPremiumUnlocked ? AppPalette.moss : AppPalette.inkSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(program.title)
                                    .font(.headline)
                                if !session.isPremiumUnlocked {
                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(AppPalette.inkSoft)
                                }
                            }

                            Text(program.category.summary)
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.inkSoft)

                            Text(program.emphasis.joined(separator: " • "))
                                .font(.caption)
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
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer()
        }
    }

    private func chip(text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppPalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppPalette.sand.opacity(0.4))
            .clipShape(Capsule())
    }
}
