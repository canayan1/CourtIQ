import SwiftUI

struct ProfileView: View {
    @Environment(DIContainer.self) private var container
    @State private var viewModel = ProfileViewModel()

    var body: some View {
        NavigationStack {
            List {
                if let profile = viewModel.profile {
                    Section {
                        HStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(CourtIQTheme.accent)
                            VStack(alignment: .leading) {
                                Text(profile.displayName).font(.headline)
                                Text(profile.email).font(.caption).foregroundStyle(.secondary)
                                Text(profile.skillLevel.rawValue)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(CourtIQTheme.accent.opacity(0.15))
                                    .foregroundStyle(CourtIQTheme.accent)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section(String(localized: "Skill Level")) {
                        Picker(String(localized: "Skill Level"), selection: $viewModel.selectedSkillLevel) {
                            ForEach(SkillLevel.allCases, id: \.self) { level in
                                Text(level.description).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if !container.premiumGate.isPremium {
                        Section {
                            PremiumUpsellBanner(message: String(localized: "Unlock unlimited quizzes, full tip archive, and more."))
                        }
                    }
                }

                Section {
                    Button(String(localized: "Sign Out"), role: .destructive) {
                        viewModel.signOut(using: container.authService)
                    }
                }
            }
            .navigationTitle(String(localized: "Profile"))
            .task {
                await viewModel.loadProfile(
                    authService: container.authService,
                    userService: container.userService
                )
            }
        }
    }
}
