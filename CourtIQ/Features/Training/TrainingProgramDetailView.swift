import SwiftUI

struct TrainingProgramDetailView: View {
    let program: TrainingProgram

    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var progress: TrainingProgressManager
    @EnvironmentObject private var progressionManager: PlayerProgressionManager
    @EnvironmentObject private var dailyQuiz: DailyQuizManager
    @EnvironmentObject private var lang: LanguageManager

    @State private var readiness = 3
    @State private var explosiveness = 3
    @State private var conditioning = 3
    @State private var notes = ""
    @State private var selectedEntryID: String?
    @State private var showPaywall = false
    @State private var selectedExercise: TrainingExercise?

    private var hasAccess: Bool {
        !program.isPremium || session.isPremiumUnlocked
    }

    private var completedCount: Int {
        progress.completedCount(programID: program.id, week: progress.selectedWeek)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                TrainSafelyBanner()

                if hasAccess {
                    weekControl
                    progressCard
                    weeklyCalendarCard
                    selectedContent
                    phaseCard
                    checkInHistoryCard
                    followOnCard
                } else {
                    lockedCard
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(program.category.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "Training")
                    .environmentObject(session)
            }
        }
        .sheet(item: $selectedExercise) { exercise in
            NavigationStack {
                ExerciseDetailSheet(exercise: exercise)
                    .environmentObject(lang)
            }
        }
        .onAppear {
            if selectedEntryID == nil {
                selectedEntryID = weeklyEntries.first?.id
            }
            loadCheckIn()
        }
        .onChange(of: progress.selectedWeek) { _, _ in
            selectedEntryID = weeklyEntries.first?.id
            loadCheckIn()
        }
    }

    private var headerCard: some View {
        // Visual-first hero: training gradient background + diagonal racket
        // motif + 8-week strip showing your current week. The textual
        // overview moves down with smaller weight so the visual carries
        // the screen.
        ZStack(alignment: .topLeading) {
            // Diagonal racket motif (decorative)
            TennisRacket(color: .white.opacity(0.20),
                         accent: .white.opacity(0.4),
                         angle: -22)
                .frame(width: 130, height: 180)
                .padding(.top, 4)
                .padding(.trailing, -10)
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: program.isPremium ? "crown.fill" : "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .accessibilityLabel(program.accessTier.title)

                    if let level = program.level {
                        Text(level.localizedTitle(for: lang.language).uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(.white.opacity(0.22))
                            )
                    }

                    Spacer()

                    // Current week / total — replaces the old plain "8 weeks"
                    Text("WK \(progress.selectedWeek) · \(program.durationWeeks)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Text(program.title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                // 8-week visual strip — filled to current week
                HStack(spacing: 4) {
                    ForEach(1...program.durationWeeks, id: \.self) { wk in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(.white.opacity(wk <= progress.selectedWeek ? 0.85 : 0.28))
                            .frame(height: 6)
                    }
                }

                Text(program.overview)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
        }
        .background(AppPalette.trainingGradient)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    // weekControl + progressCard merged into one slim row:
    // numeral-only week picker + completion progress ring.
    private var weekControl: some View {
        HStack(spacing: 14) {
            Picker("", selection: $progress.selectedWeek) {
                ForEach(1...program.durationWeeks, id: \.self) { week in
                    Text("\(week)").tag(week)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 4) {
                Text("\(completedCount)/\(program.days.count)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppPalette.clay)
                    .monospacedDigit()
            }
            .accessibilityLabel(lang.t("training.a11y_sessions_done"))
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // progressCard removed — its content (sessions completed + progress bar
    // + calendar hint) was merged into the weekControl above. The day
    // pills below give the same affordance more cheaply.
    @ViewBuilder
    private var progressCard: some View { EmptyView() }

    private var weeklyCalendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header removed — the 7 day pills below are self-evident.
            HStack(spacing: 10) {
                ForEach(weeklyEntries) { entry in
                    Button {
                        selectedEntryID = entry.id
                    } label: {
                        VStack(spacing: 8) {
                            Text(entry.label)
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)

                            Image(systemName: statusSymbol(for: entry))
                                .font(.headline)

                            Text(entry.shortTitle)
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(entry.id == selectedEntry.id ? .white : AppPalette.ink)
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .padding(.horizontal, 6)
                        .background(entry.id == selectedEntry.id ? AppPalette.clay : AppPalette.sand.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(borderColor(for: entry), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var phaseCard: some View {
        let phase = currentPhase

        // Header dropped; an icon + week-range + title row tells the
        // user which phase this is. The phase guidance paragraph stays
        // — it's content, not chrome.
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
                Text("\(phase.weekRange) · \(phase.title)")
                    .font(.subheadline.weight(.heavy))
            }
            Text(phase.guidance)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 18))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var selectedContent: some View {
        Group {
            switch selectedEntry.kind {
            case .session(let day):
                sessionDetailCard(for: day)
            case .recovery:
                recoveryCard
            case .checkIn:
                persistenceCheckCard
            }
        }
    }

    private func sessionDetailCard(for day: TrainingDayPlan) -> some View {
        let isCompleted = progress.isCompleted(programID: program.id, week: progress.selectedWeek, dayID: day.id)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(day.dayLabel) · \(day.title)")
                        .font(.title3.bold())
                    Text("\(day.type.title) · \(day.duration) · \(day.focus)")
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                }

                Spacer()

                Button {
                    let wasCompleted = progress.isCompleted(programID: program.id, week: progress.selectedWeek, dayID: day.id)
                    progress.toggleCompletion(programID: program.id, week: progress.selectedWeek, dayID: day.id)
                    if wasCompleted {
                        progressionManager.removeTrainingDay()
                        Haptics.tap()
                    } else {
                        progressionManager.recordTrainingDay()
                        progressionManager.checkAndCompleteWeek(quizHistory: dailyQuiz.sessionHistory)
                        Haptics.confirm()
                    }
                } label: {
                    Label(isCompleted ? lang.t("training.checked") : lang.t("training.mark_done"), systemImage: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isCompleted ? AppPalette.moss : AppPalette.ink)
                }
                .buttonStyle(.plain)
            }

            // Feedback banners removed — the mark-done button's state
            // already confirms completion.

            timelineBlock(icon: "flag.fill",   content: day.objective)
            timelineBlock(icon: "flame.fill",  content: day.warmup)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "dumbbell.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppPalette.clay)
                    Text(lang.t("training.main_work"))
                        .font(.subheadline.weight(.heavy))
                        .tracking(0.3)
                }
                ForEach(day.exercises) { exercise in
                    Button {
                        if exercise.hasDetail {
                            selectedExercise = exercise
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            // Visual icon for each exercise — strength tile.
                            // Replaces the previous text-only row with a more
                            // chunky, gym-card aesthetic.
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(AppPalette.clay.opacity(0.12))
                                    .frame(width: 40, height: 40)
                                Image(systemName: exerciseGlyph(for: exercise))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(AppPalette.clay)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.localizedTitle(for: lang.language))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppPalette.ink)
                                HStack(spacing: 6) {
                                    Text(exercise.prescription)
                                        .font(.caption.weight(.heavy))
                                        .foregroundStyle(AppPalette.clay)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule().fill(AppPalette.clay.opacity(0.12))
                                        )
                                    Text(exercise.localizedIntent(for: lang.language))
                                        .font(.caption)
                                        .foregroundStyle(AppPalette.inkSoft)
                                        .lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                            if exercise.hasDetail {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(AppPalette.clay)
                                    .font(.subheadline)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppPalette.sand.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppPalette.sand.opacity(0.6), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!exercise.hasDetail)
                }
            }

            timelineBlock(icon: "bolt.fill",       content: day.finisher)
            timelineBlock(icon: "figure.cooldown", content: day.recovery)
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "figure.cooldown")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
                Text(lang.t("training.recovery_reset"))
                    .font(.headline)
            }

            // Verbose hint and recommended-flow banner removed.
            // Recovery goal stays as content via the timeline block.
            timelineBlock(icon: "checkmark.seal.fill",
                          content: lang.t("training.recovery_goal"))
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var persistenceCheckCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
                Text("\(lang.t("training.week")) \(progress.selectedWeek)")
                    .font(.headline)
            }

            // Long descriptive paragraph removed — the rating rows below
            // are self-evidently a check-in.

            ratingRow(title: program.persistencePrompts[safe: 0] ?? lang.t("training.readiness"), value: $readiness)
            ratingRow(title: program.persistencePrompts[safe: 1] ?? lang.t("training.explosiveness"), value: $explosiveness)
            ratingRow(title: program.persistencePrompts[safe: 2] ?? lang.t("training.conditioning"), value: $conditioning)

            // Coach-note header removed; the placeholder + icon row below
            // is enough scaffolding.
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "square.and.pencil")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.inkSoft)
                    .padding(.top, 10)
                TextField(lang.t("training.week_reflection"), text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3, reservesSpace: true)
            }

            Button(lang.t("common.save")) {
                progress.saveCheckIn(
                    programID: program.id,
                    week: progress.selectedWeek,
                    readiness: readiness,
                    explosiveness: explosiveness,
                    conditioning: conditioning,
                    notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            .buttonStyle(.borderedProminent)

            // Verbose saved-banner removed; the rating sliders' current
            // values already show the saved state in real time.
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(lang.t("training.premium_access"), systemImage: "lock.fill")
                .font(.headline)
            Text(program.category.summary)
                .foregroundStyle(AppPalette.inkSoft)
            Text(lang.t("training.premium_desc"))
                .foregroundStyle(AppPalette.inkSoft)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(program.emphasis, id: \.self) { emphasis in
                    Label(emphasis, systemImage: "checkmark.circle")
                        .font(.subheadline)
                }
            }

            Button(lang.t("common.unlock_all")) {
                showPaywall = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var currentPhase: TrainingPhase {
        guard !program.phases.isEmpty else {
            return TrainingPhase(id: "fallback", weekRange: "Week \(progress.selectedWeek)", title: "Current Week", guidance: "Keep the sessions consistent and track how the week feels.")
        }

        switch progress.selectedWeek {
        case 1...2:
            return program.phases[safe: 0] ?? program.phases[0]
        case 3...4:
            return program.phases[safe: 1] ?? program.phases.last ?? program.phases[0]
        case 5...6:
            return program.phases[safe: 2] ?? program.phases.last ?? program.phases[0]
        case 7:
            return program.phases[safe: 3] ?? program.phases.last ?? program.phases[0]
        default:
            return program.phases[safe: 4] ?? program.phases.last ?? program.phases[0]
        }
    }

    private var cardFill: Color {
        AppPalette.parchment
    }

    private var weeklyEntries: [TrainingCalendarEntry] {
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        return labels.enumerated().map { index, label in
            if index < program.days.count {
                let day = program.days[index]
                return TrainingCalendarEntry(
                    id: day.id,
                    label: label,
                    shortTitle: day.dayLabel.replacingOccurrences(of: "Day ", with: "D"),
                    kind: .session(day)
                )
            }

            if index == 5 {
                return TrainingCalendarEntry(
                    id: "\(program.id)-recovery",
                    label: label,
                    shortTitle: "Reset",
                    kind: .recovery
                )
            }

            return TrainingCalendarEntry(
                id: "\(program.id)-checkin",
                label: label,
                shortTitle: "Check",
                kind: .checkIn
            )
        }
    }

    private var selectedEntry: TrainingCalendarEntry {
        weeklyEntries.first { $0.id == selectedEntryID }
            ?? weeklyEntries.first
            ?? TrainingCalendarEntry(
                id: "\(program.id)-default",
                label: "Mon",
                shortTitle: "D1",
                kind: .session(program.days[0])
            )
    }

    private func cardStroke(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(AppPalette.sand, lineWidth: 1)
    }

    private var checkInHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("training.checkin_history"))
                .font(.headline)

            let history = progress.checkInHistory(programID: program.id)
            if history.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(AppPalette.moss)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lang.t("training.checkin_empty_title"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.ink)
                        Text(lang.t("training.checkin_empty"))
                            .font(.caption)
                            .foregroundStyle(AppPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(12)
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ForEach(history.prefix(3), id: \.updatedAt) { checkIn in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(checkIn.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                            Text("\(lang.t("training.readiness")) \(checkIn.readiness)/5 · \(lang.t("training.explosiveness")) \(checkIn.explosiveness)/5 · \(lang.t("training.conditioning")) \(checkIn.conditioning)/5")
                                .font(.caption)
                                .foregroundStyle(AppPalette.inkSoft)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(AppPalette.sand.opacity(0.24))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private var followOnCard: some View {
        if let next = program.followOnProgram {
            let nearingEnd = progress.selectedWeek >= 6
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(AppPalette.clay)
                    Text(nearingEnd ? "What's next" : "After week 8")
                        .font(.headline)
                    Spacer()
                    Text("8 weeks")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppPalette.inkSoft)
                }

                Text(next.title)
                    .font(.title3.bold())

                Text(next.overview)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Text("7+1 progression: new adaptation stimulus for 3 weeks, a throwback test week from this plan in week 4, then consolidation through week 8.")
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink {
                    TrainingProgramDetailView(program: next)
                } label: {
                    Text(nearingEnd ? "Preview next program" : "See the progression")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)
            }
            .padding()
            .background(cardFill)
            .overlay(cardStroke(cornerRadius: 20))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func textBlock(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(content)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
        }
    }

    /// Map an exercise to a representative SF Symbol. Light heuristic
    /// based on common keywords in the exercise title — falls back to a
    /// generic dumbbell when nothing matches.
    private func exerciseGlyph(for exercise: TrainingExercise) -> String {
        let title = exercise.title.lowercased()
        switch true {
        case title.contains("jump") || title.contains("hop") || title.contains("plyo"):
            return "arrow.up.right.circle.fill"
        case title.contains("squat") || title.contains("lunge"):
            return "figure.strengthtraining.functional"
        case title.contains("push") || title.contains("press") || title.contains("bench"):
            return "figure.strengthtraining.traditional"
        case title.contains("pull") || title.contains("row"):
            return "arrow.down.right.circle.fill"
        case title.contains("plank") || title.contains("core") || title.contains("ab"):
            return "figure.core.training"
        case title.contains("sprint") || title.contains("run") || title.contains("cardio"):
            return "figure.run"
        case title.contains("stretch") || title.contains("mobility") || title.contains("foam"):
            return "figure.cooldown"
        case title.contains("balance") || title.contains("stability"):
            return "figure.mind.and.body"
        default:
            return "dumbbell.fill"
        }
    }

    /// Icon-led timeline row. Replaces the old `textBlock(title:content:)`
    /// pattern — the SF Symbol on the left carries the section meaning
    /// (warm-up, main work, finisher, recovery) instead of a redundant
    /// text header.
    private func timelineBlock(icon: String, content: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppPalette.clay)
                .frame(width: 22, alignment: .center)
                .padding(.top, 2)
            Text(content)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func feedbackBanner(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.sand.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusSymbol(for entry: TrainingCalendarEntry) -> String {
        switch entry.kind {
        case .session(let day):
            return progress.isCompleted(programID: program.id, week: progress.selectedWeek, dayID: day.id) ? "checkmark.circle.fill" : "circle"
        case .recovery:
            return "figure.cooldown"
        case .checkIn:
            return progress.hasCheckIn(programID: program.id, week: progress.selectedWeek) ? "checkmark.circle.fill" : "square.and.pencil"
        }
    }

    private func borderColor(for entry: TrainingCalendarEntry) -> Color {
        if entry.id == selectedEntry.id {
            return AppPalette.clay
        }

        switch entry.kind {
        case .session(let day):
            return progress.isCompleted(programID: program.id, week: progress.selectedWeek, dayID: day.id) ? AppPalette.moss.opacity(0.7) : AppPalette.sand
        case .recovery:
            return AppPalette.sand
        case .checkIn:
            return progress.hasCheckIn(programID: program.id, week: progress.selectedWeek) ? AppPalette.moss.opacity(0.7) : AppPalette.sand
        }
    }

    private func ratingRow(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(value.wrappedValue)/5")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft)
            }

            Stepper(value: value, in: 1...5) {
                EmptyView()
            }
            .labelsHidden()
        }
    }

    private func loadCheckIn() {
        guard let checkIn = progress.checkIn(for: program.id, week: progress.selectedWeek) else {
            readiness = 3
            explosiveness = 3
            conditioning = 3
            notes = ""
            return
        }

        readiness = checkIn.readiness
        explosiveness = checkIn.explosiveness
        conditioning = checkIn.conditioning
        notes = checkIn.notes
    }
}

private struct TrainingCalendarEntry: Identifiable {
    enum Kind {
        case session(TrainingDayPlan)
        case recovery
        case checkIn
    }

    let id: String
    let label: String
    let shortTitle: String
    let kind: Kind
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct ExerciseDetailSheet: View {
    let exercise: TrainingExercise

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.localizedTitle(for: lang.language))
                        .font(.title2.bold())
                    Text(exercise.prescription)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.clay)
                    Text(exercise.localizedIntent(for: lang.language))
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.inkSoft)
                }

                if let howTo = exercise.localizedHowTo(for: lang.language), !howTo.isEmpty {
                    section(title: lang.t("training.how_to"), icon: "figure.strengthtraining.traditional", items: howTo)
                }

                if let tennisWhy = exercise.localizedTennisWhy(for: lang.language), !tennisWhy.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(lang.t("training.tennis_why"), systemImage: "tennis.racket")
                            .font(.headline)
                            .foregroundStyle(AppPalette.ink)
                        Text(tennisWhy)
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if let watchOuts = exercise.localizedWatchOuts(for: lang.language), !watchOuts.isEmpty {
                    section(title: lang.t("training.watch_out"), icon: "exclamationmark.triangle.fill", items: watchOuts)
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("training.exercise"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(lang.t("common.done")) { dismiss() }
            }
        }
    }

    private func section(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(AppPalette.ink)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppPalette.clay)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
