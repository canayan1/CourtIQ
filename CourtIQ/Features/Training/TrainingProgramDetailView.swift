import SwiftUI

struct TrainingProgramDetailView: View {
    let program: TrainingProgram

    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var progress: TrainingProgressManager
    @EnvironmentObject private var discussionStore: DiscussionStore
    @EnvironmentObject private var progressionManager: PlayerProgressionManager
    @EnvironmentObject private var dailyQuiz: DailyQuizManager
    @EnvironmentObject private var lang: LanguageManager

    @State private var readiness = 3
    @State private var explosiveness = 3
    @State private var conditioning = 3
    @State private var notes = ""
    @State private var selectedEntryID: String?
    @State private var showPaywall = false
    @State private var threadID: String?
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

                if hasAccess {
                    weekControl
                    progressCard
                    weeklyCalendarCard
                    selectedContent
                    phaseCard
                    checkInHistoryCard
                    discussionCard
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
            if threadID == nil {
                threadID = discussionStore.thread(
                    for: ContentNodeID(targetType: .trainingSession, targetID: program.id),
                    title: program.title,
                    subtitle: program.category.summary,
                    starterPrompt: "Which day of this plan feels most useful for your tennis goals right now?"
                ).id
            }
            loadCheckIn()

            if let threadID {
                Task {
                    try? await discussionStore.refreshThread(threadID: threadID)
                }
            }
        }
        .onChange(of: progress.selectedWeek) { _, _ in
            selectedEntryID = weeklyEntries.first?.id
            loadCheckIn()
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(program.accessTier.title, systemImage: program.isPremium ? "crown.fill" : "sparkles")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Capsule())

                Spacer()

                Text("\(program.durationWeeks) weeks")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Text(program.title)
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(program.overview)
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding()
        .background(AppPalette.trainingGradient)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var weekControl: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("training.cycle_week"))
                .font(.headline)

            Picker(lang.t("training.cycle_week"), selection: $progress.selectedWeek) {
                ForEach(1...program.durationWeeks, id: \.self) { week in
                    Text("\(lang.t("training.week")) \(week)").tag(week)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(lang.t("training.week")) \(progress.selectedWeek) \(lang.t("training.progress_label"))")
                .font(.headline)

            Text("\(completedCount) \(lang.t("common.of")) \(program.days.count) \(lang.t("training.sessions_completed"))")
                .foregroundStyle(AppPalette.inkSoft)

            ProgressView(value: progress.completionRate(programID: program.id, week: progress.selectedWeek, totalDays: program.days.count))
                .tint(AppPalette.clay)

            Text(lang.t("training.calendar_hint"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var weeklyCalendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lang.t("training.weekly_calendar"))
                .font(.headline)

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

        return VStack(alignment: .leading, spacing: 10) {
            Text(lang.t("training.progression_phase"))
                .font(.headline)
            Text("\(phase.weekRange) · \(phase.title)")
                .font(.subheadline.weight(.semibold))
            Text(phase.guidance)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                    } else {
                        progressionManager.recordTrainingDay()
                        progressionManager.checkAndCompleteWeek(quizHistory: dailyQuiz.sessionHistory)
                    }
                } label: {
                    Label(isCompleted ? lang.t("training.checked") : lang.t("training.mark_done"), systemImage: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isCompleted ? AppPalette.moss : AppPalette.ink)
                }
                .buttonStyle(.plain)
            }

            if isCompleted {
                feedbackBanner(
                    title: "\(lang.t("training.week")) \(progress.selectedWeek)",
                    message: lang.t("training.marked_msg")
                )
            } else {
                feedbackBanner(
                    title: lang.t("training.open_session"),
                    message: lang.t("training.complete_hint")
                )
            }

            textBlock(title: lang.t("training.objective"), content: day.objective)
            textBlock(title: lang.t("training.warmup"), content: day.warmup)

            VStack(alignment: .leading, spacing: 8) {
                Text(lang.t("training.main_work"))
                    .font(.subheadline.weight(.semibold))
                ForEach(day.exercises) { exercise in
                    Button {
                        if exercise.hasDetail {
                            selectedExercise = exercise
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(exercise.localizedTitle(for: lang.language)) · \(exercise.prescription)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppPalette.ink)
                                Text(exercise.localizedIntent(for: lang.language))
                                    .font(.caption)
                                    .foregroundStyle(AppPalette.inkSoft)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            if exercise.hasDetail {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(AppPalette.clay)
                                    .font(.subheadline)
                                    .padding(.top, 2)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppPalette.sand.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!exercise.hasDetail)
                }
            }

            textBlock(title: lang.t("training.finisher"), content: day.finisher)
            textBlock(title: lang.t("training.recovery"), content: day.recovery)
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lang.t("training.recovery_reset"))
                .font(.title3.bold())

            Text(lang.t("training.recovery_hint"))
                .foregroundStyle(AppPalette.inkSoft)

            feedbackBanner(
                title: lang.t("training.recommended_flow"),
                message: lang.t("training.recommended_desc")
            )

            textBlock(title: lang.t("training.recovery"), content: lang.t("training.recovery_goal"))
            textBlock(title: lang.t("training.optional_note"), content: lang.t("training.heavy_week_hint"))
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var persistenceCheckCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(lang.t("training.persistence_check"))
                .font(.title3.bold())

            Text(lang.t("training.persistence_desc"))
                .foregroundStyle(AppPalette.inkSoft)

            ratingRow(title: program.persistencePrompts[safe: 0] ?? lang.t("training.readiness"), value: $readiness)
            ratingRow(title: program.persistencePrompts[safe: 1] ?? lang.t("training.explosiveness"), value: $explosiveness)
            ratingRow(title: program.persistencePrompts[safe: 2] ?? lang.t("training.conditioning"), value: $conditioning)

            VStack(alignment: .leading, spacing: 8) {
                Text(lang.t("training.coach_note"))
                    .font(.subheadline.weight(.semibold))
                TextField(lang.t("training.week_reflection"), text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3, reservesSpace: true)
            }

            Button("\(lang.t("training.week")) \(progress.selectedWeek) \(lang.t("training.persistence_check"))") {
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

            if let checkIn = progress.checkIn(for: program.id, week: progress.selectedWeek) {
                feedbackBanner(
                    title: "\(lang.t("training.week")) \(progress.selectedWeek)",
                    message: "\(lang.t("training.readiness")) \(checkIn.readiness)/5, \(lang.t("training.explosiveness").lowercased()) \(checkIn.explosiveness)/5, \(lang.t("training.conditioning").lowercased()) \(checkIn.conditioning)/5."
                )
            }
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

    private var thread: DiscussionThread? {
        guard let threadID else { return nil }
        return discussionStore.thread(withID: threadID)
    }

    private var checkInHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("training.checkin_history"))
                .font(.headline)

            let history = progress.checkInHistory(programID: program.id)
            if history.isEmpty {
                Text(lang.t("training.checkin_empty"))
                    .foregroundStyle(AppPalette.inkSoft)
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

    private var discussionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang.t("training.discussion"))
                .font(.headline)
            Text(lang.t("training.discussion_hint"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
