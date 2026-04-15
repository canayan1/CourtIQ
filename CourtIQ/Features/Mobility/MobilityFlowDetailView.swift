import SwiftUI

struct MobilityFlowDetailView: View {
    let flow: MobilityFlow

    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var discussionStore: DiscussionStore
    @State private var showPaywall = false
    @State private var threadID: String?

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
                    section(title: "Goal", content: flow.goal)
                    section(title: "Focus areas", content: flow.focusLabel)
                    section(title: "Why it matters for tennis", content: flow.whyItMatters)
                    section(title: "Instructions", content: flow.instructions)
                    section(title: "Coaching cues", content: flow.coachingCues)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sequence")
                            .font(.headline)
                        ForEach(flow.movements) { movement in
                            HStack(alignment: .top, spacing: 12) {
                                Text("•")
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(movement.title)
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(movement.duration) · \(movement.notes ?? "")")
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
        .navigationTitle(flow.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if threadID == nil {
                threadID = discussionStore.thread(
                    for: ContentNodeID(targetType: .mobilityFlow, targetID: flow.id),
                    title: flow.title,
                    subtitle: flow.goal,
                    starterPrompt: "How do you use this flow in your tennis week?"
                ).id
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
            Text("Premium flow")
                .font(.headline)

            Text("Preview is limited to the first two flows. All Access unlocks the complete mobility and recovery library plus community participation.")
                .foregroundStyle(AppPalette.inkSoft)

            Button("Unlock Mobility Library") {
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
            Text("Discussion")
                .font(.headline)

            if let thread {
                Text("\(discussionStore.commentCount(for: thread.id)) comments linked to this flow.")
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
