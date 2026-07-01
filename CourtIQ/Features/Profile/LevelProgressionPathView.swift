import SwiftUI

// MARK: - LevelProgressionPathView

struct LevelProgressionPathView: View {
    @EnvironmentObject private var manager: PlayerProgressionManager
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var dailyQuiz: DailyQuizManager
    @EnvironmentObject private var lang: LanguageManager

    @State private var showInfo = false

    // Snake display order for a 3×3 grid (weeks 1-9, zero-indexed):
    //   Row 0: 0 → 1 → 2
    //   Row 1: 5 ← 4 ← 3
    //   Row 2: 6 → 7 → 8
    private let snakeOrder = [0, 1, 2, 5, 4, 3, 6, 7, 8]

    private var nextLevelTitle: String {
        manager.currentLevel.nextLevel?.localizedTitle(for: lang.language) ?? lang.t("progression.max")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            if !manager.canProgress(isPremium: session.isPremiumUnlocked) {
                premiumGateBanner
            } else {
                pathGrid
                Divider()
                if manager.isLevelComplete {
                    levelCompleteCard
                } else {
                    weekProgressCard
                }
            }
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .sheet(isPresented: $showInfo) {
            NavigationStack { ProgressionInfoSheet() }
        }
        .onAppear {
            manager.checkAndCompleteWeek(quizHistory: dailyQuiz.sessionHistory)
        }
        .onChange(of: dailyQuiz.sessionHistory.count) { _, _ in
            manager.checkAndCompleteWeek(quizHistory: dailyQuiz.sessionHistory)
        }
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Path to \(nextLevelTitle)")
                    .font(.headline)
                Text("\(manager.completedWeekCount) of \(PlayerProgressionManager.totalWeeksToLevelUp) weeks complete")
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer()
            Button { showInfo = true } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(AppPalette.clay)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(lang.t("common.details"))
        }
    }

    // MARK: Path Grid

    private var pathGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3),
            spacing: 6
        ) {
            ForEach(Array(snakeOrder.enumerated()), id: \.offset) { displayPos, weekIdx in
                PathCircleView(
                    weekNumber: weekIdx + 1,
                    state: circleState(for: weekIdx),
                    isRowReversed: displayPos / 3 == 1  // row 1 path is R←L
                ) {
                    // Only the first unstarted circle is tappable (to begin the journey)
                    if weekIdx == manager.completedWeekCount && !manager.isStarted {
                        manager.startCurrentWeek()
                    }
                }
            }
        }
    }

    private func circleState(for weekIdx: Int) -> PathCircleState {
        if weekIdx < manager.completedWeekCount   { return .completed }
        if weekIdx == manager.completedWeekCount  { return manager.isStarted ? .current : .unstarted }
        return .locked
    }

    // MARK: Week Progress Card

    private var weekProgressCard: some View {
        let quiz = manager.quizCorrectCount(from: dailyQuiz.sessionHistory)

        return VStack(alignment: .leading, spacing: 10) {
            Text(lang.t("progression.this_week"))
                .font(.subheadline.weight(.semibold))

            reqRow(
                icon: "figure.strengthtraining.traditional",
                label: lang.t("progression.training_sessions"),
                current: manager.trainingDaysCount,
                required: PlayerProgressionManager.requiredTrainingDays
            )
            reqRow(
                icon: "figure.cooldown",
                label: lang.t("progression.mobility_flows"),
                current: manager.mobilityCount,
                required: PlayerProgressionManager.requiredMobilitySessions
            )
            reqRow(
                icon: "checkmark.circle",
                label: lang.t("progression.quiz_correct"),
                current: quiz,
                required: PlayerProgressionManager.requiredQuizCorrect
            )

            if !manager.isStarted {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption)
                        .foregroundStyle(AppPalette.clay)
                    Text(lang.t("progression.tap_to_start"))
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                }
                .padding(.top, 2)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(manager.currentLevel.accentSoft.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func reqRow(icon: String, label: String, current: Int, required: Int) -> some View {
        let done = current >= required
        return HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : icon)
                .foregroundStyle(done ? AppPalette.moss : AppPalette.inkSoft)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
            Spacer()
            Text("\(min(current, required))/\(required)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(done ? AppPalette.moss : AppPalette.ink)
        }
    }

    private var levelCompleteCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .foregroundStyle(AppPalette.moss)
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.t("progression.level_complete"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.moss)
                Text(String(format: lang.t("progression.level_reached_desc"), manager.currentLevel.localizedTitle(for: lang.language)))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.moss.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var premiumGateBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(lang.t("progression.premium_required"), systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold))
            Text(String(format: lang.t("progression.premium_gate_desc"), manager.currentLevel.localizedTitle(for: lang.language)))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.sand.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - PathCircleState

enum PathCircleState {
    case completed   // green fill + checkmark
    case current     // clay fill + pulsing ring
    case unstarted   // faint clay outline — tap to begin
    case locked      // gray, lock icon
}

// MARK: - PathCircleView

struct PathCircleView: View {
    let weekNumber: Int
    let state: PathCircleState
    let isRowReversed: Bool
    let onTap: () -> Void
    @EnvironmentObject private var lang: LanguageManager

    @State private var pulsing = false

    private let size: CGFloat = 52

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background disc
                Circle()
                    .fill(fillColor)
                    .frame(width: size, height: size)

                // Pulsing outer ring for current week
                if state == .current {
                    Circle()
                        .stroke(AppPalette.clay.opacity(0.45), lineWidth: 3)
                        .frame(width: size + 10, height: size + 10)
                        .scaleEffect(pulsing ? 1.12 : 1.0)
                        .opacity(pulsing ? 0.0 : 1.0)
                        .animation(
                            .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                            value: pulsing
                        )
                }

                // Inner content
                circleContent
                    .foregroundStyle(labelColor)

                // Direction arrow hint (small, for middle circles in reversed row)
                if isRowReversed && (weekNumber == 5 || weekNumber == 6) {
                    Image(systemName: "chevron.left")
                        .appFont(8, weight: .semibold, design: .default)
                        .foregroundStyle(.white.opacity(0.5))
                        .offset(x: 16)
                }
            }
            .frame(maxWidth: .infinity, minHeight: size + 14)
        }
        .buttonStyle(.plain)
        .disabled(state == .locked || state == .completed)
        .onAppear {
            if state == .current { pulsing = true }
        }
        .onChange(of: state) { _, newState in
            pulsing = (newState == .current)
        }
    }

    @ViewBuilder
    private var circleContent: some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark")
                .appFont(18, weight: .bold, design: .default)
        case .current:
            Text("\(weekNumber)")
                .appFont(16, weight: .bold)
        case .unstarted:
            VStack(spacing: 1) {
                Text("\(weekNumber)")
                    .appFont(14, weight: .bold)
                Text(lang.t("common.start"))
                    .appFont(9, weight: .semibold, design: .default)
                    .opacity(0.8)
            }
        case .locked:
            Image(systemName: "lock.fill")
                .appFont(14, weight: .medium, design: .default)
        }
    }

    private var fillColor: Color {
        switch state {
        case .completed: return AppPalette.moss
        case .current:   return AppPalette.clay
        case .unstarted: return AppPalette.clay.opacity(0.18)
        case .locked:    return AppPalette.sand.opacity(0.55)
        }
    }

    private var labelColor: Color {
        switch state {
        case .completed: return .white
        case .current:   return .white
        case .unstarted: return AppPalette.clay
        case .locked:    return AppPalette.inkSoft
        }
    }
}

// MARK: - ProgressionInfoSheet

struct ProgressionInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // How it works
                infoCard(title: lang.t("progression.how_it_works"), icon: "map.fill") {
                    infoItems([
                        lang.t("progression.how_1"),
                        lang.t("progression.how_2"),
                        lang.t("progression.how_3"),
                        lang.t("progression.how_4")
                    ])
                }

                // Weekly requirements
                infoCard(title: lang.t("progression.weekly_req"), icon: "checklist") {
                    VStack(alignment: .leading, spacing: 12) {
                        reqInfoRow(
                            icon: "figure.strengthtraining.traditional",
                            title: "\(PlayerProgressionManager.requiredTrainingDays) \(lang.t("progression.training_sessions"))",
                            detail: lang.t("progression.training_hint")
                        )
                        reqInfoRow(
                            icon: "figure.cooldown",
                            title: "\(PlayerProgressionManager.requiredMobilitySessions) \(lang.t("progression.mobility_flows"))",
                            detail: lang.t("progression.mobility_hint")
                        )
                        reqInfoRow(
                            icon: "checkmark.circle.fill",
                            title: "\(PlayerProgressionManager.requiredQuizCorrect) \(lang.t("progression.quiz_correct"))",
                            detail: lang.t("progression.quiz_hint")
                        )
                    }
                }

                // Player levels
                infoCard(title: lang.t("progression.player_levels"), icon: "star.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(TennisPlayerLevel.allCases, id: \.rawValue) { level in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(level.accent)
                                    .frame(width: 12, height: 12)
                                Text(level.localizedTitle(for: lang.language))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(level == .ballKid ? lang.t("common.free") : lang.t("common.premium"))
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        level == .ballKid
                                            ? AppPalette.moss.opacity(0.12)
                                            : AppPalette.clay.opacity(0.12)
                                    )
                                    .foregroundStyle(level == .ballKid ? AppPalette.moss : AppPalette.clay)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Tips
                infoCard(title: lang.t("today.tip_of_day"), icon: "lightbulb.fill") {
                    infoItems([
                        lang.t("progression.tip_1"),
                        lang.t("progression.tip_2"),
                        lang.t("progression.tip_3"),
                        lang.t("progression.tip_4")
                    ])
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("progression.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(lang.t("common.done")) { dismiss() }
            }
        }
    }

    // MARK: Helpers

    private func infoCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func infoItems(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(AppPalette.clay)
                        .font(.subheadline.weight(.bold))
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }
        }
    }

    private func reqInfoRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppPalette.clay)
                .frame(width: 22)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
        }
    }
}
