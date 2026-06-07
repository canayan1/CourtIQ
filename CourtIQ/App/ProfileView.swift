import SwiftUI
import AuthenticationServices

struct ProfileView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var progressionManager: PlayerProgressionManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var avatarManager: AvatarManager
    @EnvironmentObject private var drillManager: CourtTapDrillManager
    @EnvironmentObject private var matchManager: MatchEntryManager
    @State private var showLockerRoom = false

    @State private var showPaywall = false
    @State private var showDeleteConfirmation = false
    @State private var showResetConfirmation = false
    @State private var isDeleting = false
    @State private var isResetting = false
    @State private var showAICoach = false
    @State private var showAIPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                avatarHeaderCard
                profileHeader
                LevelProgressionPathView()
                aiCoachSection
                TacticalProfileCard()
                    .environmentObject(lang)
                    .environmentObject(drillManager)
                PlayStyleProfileCard()
                    .environmentObject(lang)
                    .environmentObject(drillManager)
                streakSection
                historySection
                betaFeedbackSection
                accountSection
                legalSection
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("profile.title"))
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "Profile")
                    .environmentObject(session)
            }
        }
        .sheet(isPresented: $showAICoach) {
            NavigationStack {
                AICoachView()
                    .environmentObject(lang)
                    .environmentObject(AIChatClient.shared)
                    .environmentObject(session)
                    .environmentObject(matchManager)
                    .environmentObject(dailyQuizManager)
                    .environmentObject(drillManager)
            }
        }
        .sheet(isPresented: $showAIPaywall) {
            AICoachPaywallStub()
                .environmentObject(lang)
                .environmentObject(session)
        }
        .confirmationDialog(lang.t("profile.delete_title"), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(lang.t("common.delete"), role: .destructive) {
                Task {
                    isDeleting = true
                    await session.deleteAccount()
                    isDeleting = false
                }
            }
            Button(lang.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(lang.t("profile.delete_msg"))
        }
        .confirmationDialog(lang.t("profile.reset_title"), isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button(lang.t("common.delete"), role: .destructive) {
                Task {
                    isResetting = true
                    await session.resetLocalData()
                    isResetting = false
                }
            }
            Button(lang.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(lang.t("profile.reset_msg"))
        }
    }

    // MARK: - Avatar header (new)

    private var avatarHeaderCard: some View {
        Button {
            Haptics.tap()
            // Refresh unlock state when entering locker — surfaces any
            // milestones the user just earned without restarting the app.
            avatarManager.checkMilestones(
                logStreak: matchManager.currentStreak,
                totalDrillsCompleted: drillManager.sessions.count,
                totalMatches: matchManager.totalEntries,
                tripleRingDays: TripleRingTracker.shared.count
            )
            showLockerRoom = true
        } label: {
            HStack(spacing: 16) {
                TennisAvatarView(config: avatarManager.config, size: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(lang.t("avatar.your_player"))
                        .font(.caption.weight(.heavy))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.inkSoft)
                    Text(lang.t("avatar.tap_to_customize"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.ink)
                    HStack(spacing: 4) {
                        Image(systemName: "lock.open.fill")
                            .font(.caption2.weight(.bold))
                        Text("\(avatarManager.unlockedIDs.count)/\(AvatarManager.unlockRules.count)")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(AppPalette.clay)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showLockerRoom) {
            NavigationStack {
                AvatarLockerRoomView()
                    .environmentObject(avatarManager)
                    .environmentObject(lang)
            }
        }
    }

    // MARK: - Profile Header

    /// IQ rating derived from the user's actual decision-training activity.
    /// Post-pivot the daily ritual is the Court Tap Drill, so drills count
    /// alongside quizzes; the streak (now fed by the daily drill) rewards
    /// consistency. Without this, a drill-only user would sit at 0 forever.
    /// Formula: 10 pts per completed quiz + 10 pts per completed drill
    /// + 5 pts per current streak day.
    private var iqRating: Int {
        dailyQuizManager.totalQuizzesCompleted * 10
            + drillManager.sessions.count * 10
            + dailyQuizManager.currentStreak * 5
    }

    private var playerLevel: TennisPlayerLevel {
        progressionManager.currentLevel
    }

    private var profileHeader: some View {
        ZStack {
            // Subtle court-lines watermark
            CourtLinesBg(color: AppPalette.clay.opacity(0.08))
                .allowsHitTesting(false)

            VStack(spacing: 18) {
                TennisPlayerBadgeView(
                    level: playerLevel,
                    iqRating: iqRating,
                    progressOverride: progressionManager.progressionProgress
                )

                VStack(spacing: 6) {
                    Text("IQ RATING")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(AppPalette.inkSoft)
                    Text("\(iqRating)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(AppPalette.ink)
                        .monospacedDigit()
                }

                VStack(spacing: 8) {
                    Text(session.displayName)
                        .font(.title3.bold())

                    HStack(spacing: 8) {
                        statusChip(
                            label: session.premiumStatus.title,
                            accent: session.isPremiumUnlocked ? AppPalette.moss : AppPalette.clay
                        )
                        statusChip(
                            label: session.isSignedInWithApple ? lang.t("profile.apple_id") : lang.t("profile.guest"),
                            accent: AppPalette.ink
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal)
        }
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Streak & Progress

    private var streakSection: some View {
        // "Progress" header dropped — the two big stat cards are
        // self-evidently progress data.
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                bigStatCard(
                    value: "\(dailyQuizManager.currentStreak)",
                    label: lang.t("profile.stat_streak"),
                    icon: "flame.fill",
                    accent: AppPalette.clay
                )
                bigStatCard(
                    value: "\(dailyQuizManager.totalQuizzesCompleted)",
                    label: lang.t("profile.stat_quizzes"),
                    icon: "checkmark.circle.fill",
                    accent: AppPalette.moss
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(lang.t("profile.stat_week"))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(dailyQuizManager.completedThisWeek) / 7 \(lang.t("common.days"))")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.inkSoft)
                }
                ProgressView(value: dailyQuizManager.weeklyCompletionRate)
                    .tint(AppPalette.clay)
            }
            .padding()
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - Quiz History (Premium)

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(lang.t("profile.section_quiz"))
                    .font(.title3.bold())
                Spacer()
                if !session.isPremiumUnlocked {
                    Text(lang.t("common.premium"))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppPalette.clay.opacity(0.12))
                        .foregroundStyle(AppPalette.clay)
                        .clipShape(Capsule())
                }
            }

            if session.isPremiumUnlocked {
                if dailyQuizManager.archivedDailyHistory.isEmpty {
                    emptyHistory
                } else {
                    ForEach(dailyQuizManager.archivedDailyHistory.prefix(5)) { record in
                        historyRow(record)
                    }
                }
            } else {
                premiumHistoryUpsell
            }
        }
    }

    private var emptyHistory: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "bolt.circle.fill")
                .font(.title)
                .foregroundStyle(AppPalette.clay)

            VStack(alignment: .leading, spacing: 4) {
                Text(lang.t("profile.empty_history_title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Text(lang.t("profile.empty_history_body"))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func historyRow(_ record: QuizSessionRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.focusLabel)
                    .font(.subheadline.weight(.semibold))
                Text(record.completedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer()
            Text(record.accuracyText)
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppPalette.clay)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var premiumHistoryUpsell: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang.t("profile.unlock_history"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
            Button(lang.t("common.unlock_all")) { showPaywall = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Beta feedback

    private var betaFeedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang.t("beta.section_title"))
                .font(.title3.bold())

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.title3)
                        .foregroundStyle(AppPalette.clay)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(lang.t("beta.prompt_title"))
                            .font(.subheadline.weight(.semibold))
                        Text(lang.t("beta.prompt_body"))
                            .font(.caption)
                            .foregroundStyle(AppPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    FeedbackComposer.openMailComposer()
                } label: {
                    Text(lang.t("beta.send"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)
            }
            .padding()
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: - Account

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lang.t("profile.section_account"))
                .font(.title3.bold())

            if !session.isSignedInWithApple {
                VStack(alignment: .leading, spacing: 10) {
                    Text(lang.t("profile.sign_in_hint"))
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
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if !session.isPremiumUnlocked {
                Button(lang.t("profile.view_plans")) { showPaywall = true }
                    .buttonStyle(.borderedProminent)
            } else {
                Button(lang.t("profile.manage_sub")) { session.openManageSubscriptions() }
                    .buttonStyle(.borderedProminent)
            }

            Button(lang.t("profile.restore")) {
                Task { await session.restorePurchases() }
            }
            .buttonStyle(.bordered)

            Button(isResetting ? lang.t("common.resetting") : lang.t("profile.reset_title"), role: .destructive) {
                showResetConfirmation = true
            }
            .buttonStyle(.bordered)
            .disabled(isResetting)

            Button(session.isGuest ? lang.t("profile.leave_guest") : lang.t("profile.sign_out")) {
                session.signOut()
            }
            .buttonStyle(.bordered)

            if session.isSignedInWithApple {
                Button(isDeleting ? lang.t("common.deleting") : lang.t("common.delete"), role: .destructive) {
                    showDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
                .disabled(isDeleting)
            }
        }
    }

    // MARK: - Legal

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lang.t("profile.section_language"))
                .font(.title3.bold())

            HStack(spacing: 10) {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        lang.language = option
                    } label: {
                        VStack(spacing: 4) {
                            Text(option.regionLabel)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                            Text(option.displayName)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(lang.language == option ? AppPalette.clay : AppPalette.parchment)
                        .foregroundStyle(lang.language == option ? .white : AppPalette.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(
                                    lang.language == option ? AppPalette.clay : AppPalette.sand,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// AI Coach entry card. AI Coach is the single paid feature; every
    /// other surface in the app is free. Access is granted when ANY of
    /// these hold:
    ///   • `aiCoachOpenToAll` (kill-switch to reopen to everyone)
    ///   • a real premium entitlement (StoreKit purchase)
    ///   • a dev-allowlisted account (DEBUG builds only — TestFlight
    ///     dogfooding; see `isDevAllowlistedAccount`), so the owner can
    ///     test the gated feature on a real device without faking a
    ///     purchase. This path does not exist in App Store builds.
    private static let aiCoachOpenToAll = false

    private var aiCoachSection: some View {
        let isPremium = Self.aiCoachOpenToAll
            || session.subscriptionManager.entitlementState.isPremium
            || Self.isDevAllowlistedAccount(session.profileStore.profile?.email)
        return Button {
            if isPremium {
                showAICoach = true
            } else {
                showAIPaywall = true
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppPalette.clay.opacity(0.14))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppPalette.clay)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(lang.t("ai.title"))
                            .font(.headline)
                            .foregroundStyle(AppPalette.ink)
                        if !isPremium {
                            Text(lang.t("ai.premium_badge"))
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppPalette.gold.opacity(0.18))
                                .foregroundStyle(AppPalette.gold)
                                .clipShape(Capsule())
                        }
                    }
                    Text(lang.t("ai.card_subtitle"))
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var notificationsSection: some View {
        // Wired in v1.1.C — surfaces the per-channel toggles for the
        // daily quiz reminder, the match-log nudge, and the weekly digest.
        // Kept above the legal section so it sits next to the user-controls
        // band rather than at the very bottom.
        NavigationLink {
            NotificationSettingsView()
        } label: {
            HStack {
                Label(lang.t("notif.settings.title"), systemImage: "bell.badge.fill")
                    .font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang.t("profile.section_policies"))
                .font(.title3.bold())

            notificationsSection

            ForEach(LegalDocument.allCases) { document in
                NavigationLink {
                    LegalDocumentView(document: document)
                } label: {
                    HStack {
                        Text(document.title)
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppPalette.sand, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func bigStatCard(value: String, label: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accent)
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statusChip(label: String, accent: Color) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(accent.opacity(0.14))
            .foregroundStyle(accent)
            .clipShape(Capsule())
    }

    /// Developer-only AI Coach access for TestFlight dogfooding, so the
    /// owner can test the gated feature on a real device without faking a
    /// StoreKit purchase.
    ///
    /// This is compiled in **DEBUG builds only**. App Store (Release)
    /// builds always return `false` here — no allowlist, no developer
    /// email, and therefore no hidden/backdoor entitlement path in the
    /// shipped binary (and no personal PII embedded in it).
    private static func isDevAllowlistedAccount(_ email: String?) -> Bool {
        #if DEBUG
        guard let raw = email?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return false }
        let devAccessAllowlist: Set<String> = [
            "canayan93@gmail.com"
        ]
        return devAccessAllowlist.contains(raw)
        #else
        return false
        #endif
    }
}
