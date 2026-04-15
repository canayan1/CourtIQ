import SwiftUI

struct TrainingProgramDetailView: View {
    let program: TrainingProgram

    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var progress: TrainingProgressManager
    @EnvironmentObject private var discussionStore: DiscussionStore

    @State private var readiness = 3
    @State private var explosiveness = 3
    @State private var conditioning = 3
    @State private var notes = ""
    @State private var selectedEntryID: String?
    @State private var showPaywall = false
    @State private var threadID: String?

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
            Text("Cycle Week")
                .font(.headline)

            Picker("Cycle Week", selection: $progress.selectedWeek) {
                ForEach(1...program.durationWeeks, id: \.self) { week in
                    Text("Week \(week)").tag(week)
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
            Text("Week \(progress.selectedWeek) Progress")
                .font(.headline)

            Text("\(completedCount) of \(program.days.count) sessions completed")
                .foregroundStyle(AppPalette.inkSoft)

            ProgressView(value: progress.completionRate(programID: program.id, week: progress.selectedWeek, totalDays: program.days.count))
                .tint(AppPalette.clay)

            Text("Pick a day from the calendar, open the session, and keep the week checked off as you go.")
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
            Text("Weekly Calendar")
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
            Text("Current Progression Phase")
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
                    progress.toggleCompletion(programID: program.id, week: progress.selectedWeek, dayID: day.id)
                } label: {
                    Label(isCompleted ? "Checked" : "Mark Done", systemImage: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isCompleted ? AppPalette.moss : AppPalette.ink)
                }
                .buttonStyle(.plain)
            }

            if isCompleted {
                feedbackBanner(
                    title: "Logged for week \(progress.selectedWeek)",
                    message: "Nice work. This day is now checked and will stay saved in your account."
                )
            } else {
                feedbackBanner(
                    title: "Open session",
                    message: "Complete the work below, then tap Mark Done to keep this calendar day checked."
                )
            }

            textBlock(title: "Objective", content: day.objective)
            textBlock(title: "Warm-up", content: day.warmup)

            VStack(alignment: .leading, spacing: 8) {
                Text("Main work")
                    .font(.subheadline.weight(.semibold))
                ForEach(day.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(exercise.title) · \(exercise.prescription)")
                            .font(.subheadline.weight(.semibold))
                        Text(exercise.intent)
                            .font(.caption)
                            .foregroundStyle(AppPalette.inkSoft)
                    }
                }
            }

            textBlock(title: "Finisher", content: day.finisher)
            textBlock(title: "Recovery", content: day.recovery)
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recovery Reset")
                .font(.title3.bold())

            Text("Use this day for a full reset so the next training block still feels explosive.")
                .foregroundStyle(AppPalette.inkSoft)

            feedbackBanner(
                title: "Recommended flow",
                message: "20-30 min easy walk or bike, hip and thoracic mobility, calves, adductors, and soft tissue work."
            )

            textBlock(title: "Goal", content: "Come back fresher, not flat. Keep blood flow high and overall stress low.")
            textBlock(title: "Optional note", content: "If the week felt heavy, use this day to downshift before the persistence check.")
        }
        .padding()
        .background(cardFill)
        .overlay(cardStroke(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var persistenceCheckCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Persistence Check")
                .font(.title3.bold())

            Text("Finish the week with a short check-in so your progress stays visible across the full 8-week run.")
                .foregroundStyle(AppPalette.inkSoft)

            ratingRow(title: program.persistencePrompts[safe: 0] ?? "Readiness", value: $readiness)
            ratingRow(title: program.persistencePrompts[safe: 1] ?? "Explosiveness", value: $explosiveness)
            ratingRow(title: program.persistencePrompts[safe: 2] ?? "Conditioning", value: $conditioning)

            VStack(alignment: .leading, spacing: 8) {
                Text("Coach note")
                    .font(.subheadline.weight(.semibold))
                TextField("What improved or felt heavy this week?", text: $notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3, reservesSpace: true)
            }

            Button("Save Week \(progress.selectedWeek) Check") {
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
                    title: "Week \(progress.selectedWeek) saved",
                    message: "Readiness \(checkIn.readiness)/5, explosiveness \(checkIn.explosiveness)/5, conditioning \(checkIn.conditioning)/5."
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
            Label("Premium Access", systemImage: "lock.fill")
                .font(.headline)
            Text(program.category.summary)
                .foregroundStyle(AppPalette.inkSoft)
            Text("This first premium layer unlocks category-specific 8-week plans like better footwork, stronger shots, better flexibility, and match conditioning.")
                .foregroundStyle(AppPalette.inkSoft)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(program.emphasis, id: \.self) { emphasis in
                    Label(emphasis, systemImage: "checkmark.circle")
                        .font(.subheadline)
                }
            }

            Button("Unlock All Access") {
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
        weeklyEntries.first { $0.id == selectedEntryID } ?? weeklyEntries[0]
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
            Text("Check-in History")
                .font(.headline)

            let history = progress.checkInHistory(programID: program.id)
            if history.isEmpty {
                Text("Save your first weekly persistence check to build a history for this plan.")
                    .foregroundStyle(AppPalette.inkSoft)
            } else {
                ForEach(history.prefix(3), id: \.updatedAt) { checkIn in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(checkIn.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                            Text("Readiness \(checkIn.readiness)/5 · Explosiveness \(checkIn.explosiveness)/5 · Conditioning \(checkIn.conditioning)/5")
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
            Text("Discussion")
                .font(.headline)

            if let thread {
                Text("\(discussionStore.commentCount(for: thread.id)) comments linked to this training plan.")
                    .foregroundStyle(AppPalette.inkSoft)

                NavigationLink {
                    DiscussionThreadView(threadID: thread.id)
                } label: {
                    Text("Open Thread")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
            }
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
