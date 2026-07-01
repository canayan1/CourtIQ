import SwiftUI

/// Programs level of the Train tree: the free 8-week featured block (trimmed of
/// its descriptive paragraphs) plus the premium training tracks. Premium
/// gating + the moss/inkSoft accent swap are preserved.
struct TrainProgramsView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager

    private let programs = TrainingProgram.allPrograms

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                featuredCard
                premiumTracks
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("train.programs"))
    }

    private var featuredCard: some View {
        let program = TrainingProgram.featuredProgram

        return ZStack(alignment: .topTrailing) {
            TennisRacket(color: .white.opacity(0.16), accent: .white.opacity(0.35), angle: -22)
                .frame(width: 130, height: 182)
                .offset(x: 28, y: -8)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                programSectionHeader(title: lang.t("training.free_foundation"),
                                     subtitle: lang.t("training.start_here"),
                                     onPhoto: true)

                Text(program.localizedTitle(for: lang.language))
                    .font(.title3.bold())

                Text(lang.t("training.block_title"))
                    .font(.system(.title2, design: .rounded).weight(.black))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    ForEach(1...8, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(.white.opacity(i <= 2 ? 0.85 : 0.28))
                            .frame(height: 6)
                    }
                }

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
        // Layer the duotone photo OVER the existing brand gradient (ZStack:
        // gradient then photo), mirroring Home's hero / the Train flagship.
        .background(
            ZStack {
                AppPalette.trainingGradient
                BrandedPhotoBackground(name: "PhotoCourt", scrim: .hero)
            }
        )
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var premiumTracks: some View {
        VStack(alignment: .leading, spacing: 14) {
            programSectionHeader(title: lang.t("training.premium_tracks"),
                                 subtitle: session.isPremiumUnlocked ? lang.t("training.unlocked") : lang.t("training.locked"))

            ForEach(programs.filter(\.isPremium)) { program in
                NavigationLink {
                    TrainingProgramDetailView(program: program)
                } label: {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: program.category.symbolName)
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(session.isPremiumUnlocked ? AppPalette.moss : AppPalette.inkSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Text(program.localizedTitle(for: lang.language))
                            .font(.headline)
                            .foregroundStyle(.white)

                        if !session.isPremiumUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                        }

                        Spacer()
                    }
                    .padding()
                    .brandedPhoto("PhotoCourt", scrim: .bottom, cornerRadius: 22)
                }
                .buttonStyle(PressableCardStyle())
            }
        }
    }

    /// `onPhoto` flips the subtitle to a legible light tint when the header sits
    /// on a duotone photo surface (the featured card); off-photo it keeps the
    /// original inkSoft.
    private func programSectionHeader(title: String, subtitle: String, onPhoto: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(onPhoto ? Color.white.opacity(0.85) : AppPalette.inkSoft)
            }
            Spacer()
        }
    }
}
