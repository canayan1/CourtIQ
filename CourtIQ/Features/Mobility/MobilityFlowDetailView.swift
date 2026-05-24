import SwiftUI

struct MobilityFlowDetailView: View {
    let flow: MobilityFlow

    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var discussionStore: DiscussionStore
    @EnvironmentObject private var progressionManager: PlayerProgressionManager
    @EnvironmentObject private var lang: LanguageManager
    @State private var showPaywall = false
    @State private var threadID: String?
    @State private var mobilityRecorded = false

    private var previewFlowIDs: Set<String> {
        Set(MobilityFlow.sampleFlows.prefix(2).map(\.id))
    }

    private var hasAccess: Bool {
        session.isPremiumUnlocked || previewFlowIDs.contains(flow.id)
    }

    private var thread: DiscussionThread? {
        guard let threadID else { return nil }
        return discussionStore.thread(withID: threadID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                TrainSafelyBanner()

                if !hasAccess {
                    lockedCard
                } else {
                    // Section headers replaced with icon-led timeline rows.
                    // The icon column on the left teaches the section meaning;
                    // the content paragraph carries the lesson.
                    VStack(alignment: .leading, spacing: 14) {
                        iconRow(systemImage: "target",
                                content: flow.localizedGoal(for: lang.language),
                                a11y: lang.t("mobility.goal"))
                        iconRow(systemImage: "tennis.racket",
                                content: flow.localizedWhyItMatters(for: lang.language),
                                a11y: lang.t("mobility.why"))
                        iconRow(systemImage: "list.bullet",
                                content: flow.localizedInstructions(for: lang.language),
                                a11y: lang.t("mobility.instructions"))
                        iconRow(systemImage: "quote.bubble.fill",
                                content: flow.localizedCoachingCues(for: lang.language),
                                a11y: lang.t("mobility.cues"))
                    }
                    .padding()
                    .background(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    // Sequence — numbered circles + a small procedural
                    // figure thumbnail per movement, so the list itself
                    // visually previews each pose.
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(flow.movements.enumerated()), id: \.element.id) { idx, movement in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .stroke(AppPalette.clay, lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                    Text("\(idx + 1)")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundStyle(AppPalette.clay)
                                }

                                AthleteFigureCanvas(
                                    staticPose: AthletePose.match(forTitle: movement.title)
                                )
                                .frame(width: 56, height: 64)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(movement.localizedTitle(for: lang.language))
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(movement.duration) · \(movement.localizedNotes(for: lang.language) ?? "")")
                                        .font(.caption)
                                        .foregroundStyle(AppPalette.inkSoft)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

                discussionSection
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(flow.localizedTitle(for: lang.language))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if hasAccess && !mobilityRecorded {
                progressionManager.recordMobilitySession()
                MobilityFlowSessionTracker.shared.recordStarted()
                mobilityRecorded = true
            }

            if threadID == nil {
                threadID = discussionStore.thread(
                    for: ContentNodeID(targetType: .mobilityFlow, targetID: flow.id),
                    title: flow.title,
                    subtitle: flow.goal,
                    starterPrompt: "How do you use this flow in your tennis week?"
                ).id
            }

            if let threadID {
                Task {
                    try? await discussionStore.refreshThread(threadID: threadID)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            NavigationStack {
                PaywallView(source: "Mobility")
                    .environmentObject(session)
            }
        }
    }

    private var header: some View {
        // Hero is now a live procedural-figure animation cycling through
        // up to three poses derived from the flow's first few movements.
        // Falls back to a sensible default sequence so we always show
        // motion even when the lookup misses.
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                CourtTopDown(surface: .clay, lineOpacity: 0.20)
                    .opacity(0.28)
                    .frame(width: 120, height: 180)
                    .offset(x: 100, y: 0)
                    .allowsHitTesting(false)

                AthleteFigureCanvas(
                    poseSequence: heroPoseSequence,
                    loopDuration: 6.0
                )
                .frame(width: 240, height: 240)
            }
            .frame(height: 240)

            VStack(alignment: .leading, spacing: 4) {
                Text(flow.localizedTitle(for: lang.language))
                    .font(.title2.bold())
                HStack(spacing: 12) {
                    Label(flow.duration, systemImage: "timer")
                    Label(flow.focusLabel, systemImage: "target")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppPalette.inkSoft)
            }
        }
    }

    /// Build the hero's pose sequence from the first three movements in
    /// the flow. If the flow is shorter, pad with a neutral standing
    /// pose so the animation always has something to interpolate against.
    private var heroPoseSequence: [AthletePose] {
        let derived = flow.movements
            .prefix(3)
            .map { AthletePose.match(forTitle: $0.title) }
        guard !derived.isEmpty else { return [.standing, .forwardFold, .lungeTwist] }
        return derived.count == 1 ? [derived[0], .standing] : Array(derived)
    }

    private var lockedCard: some View {
        // Crown glyph + 1-line label + unlock button. Locked-desc paragraph
        // removed — the crown + locked flow list above signal it.
        VStack(spacing: 14) {
            Image(systemName: "crown.fill")
                .font(.system(size: 36))
                .foregroundStyle(AppPalette.gold)
            Text(lang.t("mobility.premium"))
                .font(.headline)
            Button(lang.t("mobility.unlock")) { showPaywall = true }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var discussionSection: some View {
        // Header + 12-word hint collapsed to icon + chevron row.
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppPalette.clay)
            Text(lang.t("training.discussion"))
                .font(.subheadline.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    /// Icon-led timeline row used inside the unified mobility card.
    private func iconRow(systemImage: String, content: String, a11y: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppPalette.clay)
                .frame(width: 22, alignment: .center)
                .padding(.top, 2)
                .accessibilityLabel(a11y)
            Text(content)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func section(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
