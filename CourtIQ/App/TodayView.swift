import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var dailyQuizManager: DailyQuizManager
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var tipManager: TipManager
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var drillManager: CourtTapDrillManager
    @ObservedObject private var tennisProfileStore = TennisProfileStore.shared

    // Tip body is expanded by default — collapsing was hiding the actual
    // content (each tip is only ~80 words) and made the card feel empty.
    @State private var tipExpanded = true
    @State private var showDrill = false

    private var tip: DailyTip { tipManager.todayTip }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                ThreeRingsCard()
                tennisProfileCard
                drillCard
                ProShotCard()
                tipCard
                mobilityCard
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("tab.today"))
        .fullScreenCover(isPresented: $showDrill) {
            NavigationStack {
                CourtTapDrillView()
                    .environmentObject(lang)
                    .environmentObject(drillManager)
            }
        }
    }

    // MARK: - Tennis Profile entry

    @ViewBuilder
    private var tennisProfileCard: some View {
        let copy = TennisProfileCopy(lang: lang.language)
        if let profile = tennisProfileStore.profile {
            NavigationLink {
                TennisProfileResultView(profile: profile)
            } label: {
                tennisProfileRow(
                    icon: "figure.tennis", tint: AppPalette.moss,
                    eyebrow: copy.sectionTitle,
                    title: "\(copy.levelTitle(profile.result.level)) · \(copy.archetypeTitle(profile.result.archetype))"
                )
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                TennisProfileQuestionnaireView()
            } label: {
                tennisProfileRow(
                    icon: "figure.tennis", tint: AppPalette.clay,
                    eyebrow: copy.entryTitle,
                    title: copy.entrySubtitle
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func tennisProfileRow(icon: String, tint: Color, eyebrow: String, title: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(tint.opacity(0.16)).frame(width: 46, height: 46)
                Image(systemName: icon).font(.title3).foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow).font(.caption.weight(.heavy)).tracking(0.4).foregroundStyle(AppPalette.inkSoft)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Daily Court Tap Drill (the new daily ritual)

    private var drillCard: some View {
        let done = drillManager.completedToday
        let session = drillManager.todaysSession
        let pct = session.map { Double($0.score) / Double($0.maxScore) } ?? 0

        return ZStack(alignment: .topTrailing) {
            // Court watermark
            CourtTopDown(surface: .clay, lineOpacity: 0.35)
                .opacity(0.10)
                .frame(width: 90, height: 140)
                .offset(x: 8, y: 8)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppPalette.clay)
                    Text(lang.t("drill.card_kicker"))
                        .font(.caption.weight(.heavy))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(AppPalette.clay)
                    Spacer()
                    if done {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppPalette.moss)
                    }
                }

                Text(lang.t("drill.card_title"))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppPalette.ink)

                if let session = session {
                    HStack(spacing: 8) {
                        ForEach(Array(session.taps.enumerated()), id: \.offset) { _, tap in
                            Text(tap.zone.emoji)
                                .font(.system(size: 20))
                        }
                        Spacer()
                        Text("\(Int(pct * 100))%")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppPalette.ink)
                            .monospacedDigit()
                    }
                }

                Button {
                    showDrill = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: done ? "arrow.clockwise" : "play.fill")
                        Text(done ? lang.t("drill.replay") : lang.t("drill.start"))
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppPalette.clay)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Hero

    private var heroCard: some View {
        // ZStack uses .topLeading so the content VStack fills the natural
        // leading edge instead of being pushed right by a topTrailing
        // alignment. The corner ball positions itself explicitly via its
        // own maxWidth + .topTrailing frame.
        ZStack(alignment: .topLeading) {
            // Court hero background
            CourtPerspective(surface: .clay)
                .overlay(
                    LinearGradient(
                        colors: [AppPalette.clay.opacity(0.55), AppPalette.ink.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Trajectory arc
            TrajectoryArc(color: .white.opacity(0.55))
                .padding(.horizontal, 12)
                .allowsHitTesting(false)

            // Hero is intentionally CTA-free. The single quiz entry point
            // lives on the Daily IQ card below.
            VStack(alignment: .leading, spacing: 16) {
                Text(greetingLine)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if session.hasCompletedOnboarding,
                   !session.currentImprovementFocus.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.caption.weight(.bold))
                        Text(session.currentImprovementFocus.uppercased())
                            .font(.caption.weight(.heavy))
                            .tracking(0.8)
                    }
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(.white.opacity(0.14))
                    )
                }

                HStack(spacing: 12) {
                    iconStat(
                        systemImage: "flame.fill",
                        value: "\(dailyQuizManager.currentStreak)",
                        showGrace: dailyQuizManager.streakGraceActive,
                        accessibilityLabel: lang.t("today.a11y_day_streak")
                    )
                    iconStat(
                        systemImage: "calendar",
                        value: "\(dailyQuizManager.completedThisWeek)/7",
                        showGrace: false,
                        accessibilityLabel: lang.t("today.a11y_this_week")
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Corner felt-seamed ball — positioned top-right via an explicit
            // alignment frame so it doesn't pull content with it.
            TennisBall()
                .frame(width: 64, height: 64)
                .padding(.top, -8)
                .padding(.trailing, -8)
                .opacity(0.95)
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    /// Single-line greeting — focus context lives in the chip below the
    /// greeting, so the greeting itself stays a short hello.
    private var greetingLine: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return lang.t("today.greeting_morning")
        case 12..<17: return lang.t("today.greeting_afternoon")
        default:      return lang.t("today.greeting_evening")
        }
    }

    /// Icon-led stat pill — no word label, just icon + number. The icon
    /// teaches the meaning; an accessibility label preserves it for
    /// VoiceOver.
    private func iconStat(systemImage: String, value: String, showGrace: Bool,
                          accessibilityLabel: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            if showGrace {
                // Snowflake = grace day in play. `.help` is macOS-only and
                // a no-op on iOS; we expose the hint via VoiceOver instead
                // (the parent stack's accessibilityLabel below covers value
                // semantics; this hint adds the grace context).
                Image(systemName: "snowflake")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .accessibilityHint(lang.t("today.streak_grace_hint"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 0.6)
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accessibilityLabel): \(value)")
    }

    // MARK: - Tip of the Day

    private var tipCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon-only category indicator. Card aesthetic (lightbulb
            // accent + parchment) already says "tip of the day"; the
            // textual "Tip of the day" label and category name were
            // redundant chrome.
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppPalette.gold)
                    .font(.subheadline.weight(.bold))
                Image(systemName: tip.category.systemImage)
                    .foregroundStyle(AppPalette.clay)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityLabel(tip.category.title)
                Spacer()
            }

            Text(tip.title)
                .font(.headline)

            if tipExpanded {
                Text(tip.body)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                if let source = tip.source {
                    Text("— \(source)")
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft.opacity(0.7))
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    tipExpanded.toggle()
                }
            } label: {
                Image(systemName: tipExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppPalette.clay)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                    .contentShape(Rectangle())
                    .accessibilityLabel(tipExpanded ? lang.t("today.show_less") : lang.t("today.read_more"))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // Daily quiz lives in the Practice tab now (post-pivot) — the daily
    // ritual on Today is Drill + Pro Shot + Rings + Tip + Mobility. Quiz
    // stats still flow through DailyQuizManager via Practice completions.

    // MARK: - Mobility

    @ViewBuilder
    private var mobilityCard: some View {
        // Safe lookup — show nothing if content hasn't loaded yet.
        let flows = MobilityFlow.sampleFlows
        if let flow = flows.first(where: { $0.type == .quickReset }) ?? flows.first {
            // Card opens with mobility glyph + flow title (no "Quick reset"
            // header — the glyph + duration chip already convey it).
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TennisGlyph(kind: .mobility, color: AppPalette.clay, size: 20)
                    Text(flow.localizedTitle(for: lang.language))
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    if !session.isPremiumUnlocked {
                        Image(systemName: "crown.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppPalette.gold)
                            .accessibilityLabel(lang.t("common.premium"))
                    }
                }

                HStack(spacing: 8) {
                    infoChip(systemImage: "timer", text: flow.duration)
                    infoChip(systemImage: "figure.walk", text: flow.focusLabel)
                }

                NavigationLink {
                    MobilityFlowDetailView(flow: flow)
                } label: {
                    Text(session.isPremiumUnlocked ? lang.t("today.open_flow") : lang.t("today.preview_flow"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    // MARK: - Helpers

    private var premiumBadge: some View {
        Text(lang.t("common.premium"))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppPalette.clay.opacity(0.12))
            .foregroundStyle(AppPalette.clay)
            .clipShape(Capsule())
    }

    private func infoChip(systemImage: String, text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppPalette.sand.opacity(0.5))
            .clipShape(Capsule())
    }
}
