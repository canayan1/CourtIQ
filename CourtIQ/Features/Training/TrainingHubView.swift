import SwiftUI

struct TrainingHubView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var trainingProgress: TrainingProgressManager
    @EnvironmentObject private var lang: LanguageManager

    private let programs = TrainingProgram.allPrograms

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard
                frequencyBanner
                featuredCard
                premiumTracks
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("tab.training"))
    }

    // MARK: - Onboarding frequency personalisation

    @ViewBuilder
    private var frequencyBanner: some View {
        let freq = UserDefaults.standard.string(forKey: "CourtIQ.onboardingFrequency") ?? ""

        if !freq.isEmpty, let info = frequencyInfo(for: freq) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 20))
                    .foregroundStyle(AppPalette.moss)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plan matched to \(info.days)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(AppPalette.moss)
                    Text(info.note)
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .background(AppPalette.moss.opacity(0.09))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AppPalette.moss.opacity(0.22), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func frequencyInfo(for freq: String) -> (days: String, note: String)? {
        switch freq {
        case "1-2": return ("1–2 days/week", "The foundation plan fits neatly into two sessions — exactly your schedule.")
        case "3-4": return ("3–4 days/week", "The 4-day weekly loop in the foundation plan is built for your rhythm.")
        case "5+":  return ("5+ days/week", "High-frequency players get the most from the Match Conditioning track once premium is unlocked.")
        default:    return nil
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lang.t("training.subtitle"))
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppPalette.inkSoft)

            Text(lang.t("training.desc"))
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(lang.t("training.long_desc"))
                .foregroundStyle(AppPalette.inkSoft)

            HStack(spacing: 12) {
                chip(text: lang.t("training.8week_cycle"), systemImage: "calendar")
                chip(text: lang.t("training.persistence_checks"), systemImage: "chart.line.uptrend.xyaxis")
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

        return ZStack(alignment: .topTrailing) {
            // Diagonal racket motif behind content
            TennisRacket(color: .white.opacity(0.16), accent: .white.opacity(0.35), angle: -22)
                .frame(width: 130, height: 182)
                .offset(x: 28, y: -8)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(title: lang.t("training.free_foundation"),
                              subtitle: lang.t("training.start_here"))

                Text(program.title)
                    .font(.title3.bold())

                VStack(alignment: .leading, spacing: 6) {
                    Text("8-Week Training Block")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(.white)
                    Text("Plyometrics, hypertrophy, explosiveness, conditioning")
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(.white.opacity(0.88))
                }

                // 8-week strip
                HStack(spacing: 4) {
                    ForEach(1...8, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(.white.opacity(i <= 2 ? 0.85 : 0.28))
                            .frame(height: 6)
                    }
                }

                Text("Repeat the weekly structure for 8 weeks, log each session, and compare your persistence checks over time.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))

                NavigationLink {
                    TrainingProgramDetailView(program: program)
                } label: {
                    Text(lang.t("training.open_plan"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .background(AppPalette.trainingGradient)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var premiumTracks: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: lang.t("training.premium_tracks"), subtitle: session.isPremiumUnlocked ? lang.t("training.unlocked") : lang.t("training.locked"))

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
