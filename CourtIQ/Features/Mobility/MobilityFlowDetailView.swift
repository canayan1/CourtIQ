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

                if !hasAccess {
                    lockedCard
                } else {
                    section(title: lang.t("mobility.goal"), content: flow.localizedGoal(for: lang.language))
                    section(title: lang.t("mobility.focus_areas"), content: flow.focusLabel)
                    section(title: lang.t("mobility.why"), content: flow.localizedWhyItMatters(for: lang.language))
                    section(title: lang.t("mobility.instructions"), content: flow.localizedInstructions(for: lang.language))
                    section(title: lang.t("mobility.cues"), content: flow.localizedCoachingCues(for: lang.language))

                    VStack(alignment: .leading, spacing: 12) {
                        Text(lang.t("mobility.sequence"))
                            .font(.headline)
                        ForEach(flow.movements) { movement in
                            HStack(alignment: .top, spacing: 12) {
                                Text("•")
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
        VStack(alignment: .leading, spacing: 8) {
            Text(flow.title)
                .font(.title2.bold())
            HStack(spacing: 12) {
                Label(flow.duration, systemImage: "timer")
                Label(flow.focusLabel, systemImage: "target")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppPalette.inkSoft)
        }
    }

    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.t("mobility.premium"))
                .font(.headline)

            Text(lang.t("mobility.locked_desc"))
                .foregroundStyle(AppPalette.inkSoft)

            Button(lang.t("mobility.unlock")) {
                showPaywall = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var discussionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(lang.t("training.discussion"))
                .font(.headline)
            Text(lang.t("training.discussion_hint"))
                .font(.subheadline)
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
