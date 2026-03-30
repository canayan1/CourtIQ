import SwiftUI

struct MobilityFlowDetailView: View {
    let flow: MobilityFlow
    @EnvironmentObject private var session: UserSessionManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if !session.isPremiumUnlocked {
                    premiumBanner
                }

                section(title: "Goal", content: flow.goal)
                section(title: "Focus areas", content: flow.focusLabel)
                section(title: "Why it matters for tennis", content: flow.whyItMatters)
                section(title: "Instructions", content: flow.instructions)

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
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                discussionSection

                if !session.isPremiumUnlocked {
                    Button("Premium access coming soon") {}
                        .buttonStyle(.borderedProminent)
                        .disabled(true)
                }
            }
            .padding()
        }
        .navigationTitle(flow.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(flow.title)
                .font(.title2.bold())
            Text(flow.duration)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var premiumBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.white)
                .padding(8)
                .background(Color.gray)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text("Premium flow")
                    .font(.headline)
                Text("This routine is part of the mobility and recovery library. Unlock premium to save your favorites and track flow progress.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var discussionSection: some View {
        let threadCount = DiscussionRepository.threadCount(for: .mobilityFlow, targetID: flow.id)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Discussion")
                .font(.headline)
            if threadCount > 0 {
                Text("\(threadCount) thread(s) available for this flow.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Discussion foundation is ready for this flow.")
                    .foregroundStyle(.secondary)
            }
            Button("Join discussion") {}
                .buttonStyle(.bordered)
                .disabled(true)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func section(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(content)
                .foregroundStyle(.secondary)
        }
    }
}