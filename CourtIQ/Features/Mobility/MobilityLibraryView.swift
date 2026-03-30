import SwiftUI

struct MobilityLibraryView: View {
    @EnvironmentObject private var session: UserSessionManager
    private let flows = MobilityFlow.sampleFlows

    var body: some View {
        List {
            premiumHeader

            ForEach(MobilityFlowType.allCases) { type in
                Section(header: Text(type.title)) {
                    ForEach(flows.filter { $0.type == type }) { flow in
                        NavigationLink {
                            MobilityFlowDetailView(flow: flow)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(flow.title)
                                        .font(.headline)
                                    Text(flow.goal)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(flow.duration)
                                        .font(.caption.weight(.semibold))
                                    Text(flow.focusLabel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .navigationTitle("Mobility Library")
        .listStyle(.insetGrouped)
    }

    private var premiumHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Mobility & Recovery")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(session.premiumStatus.title)
                    .font(.caption.weight(.semibold))
                    .padding(6)
                    .background(session.isPremiumUnlocked ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text("A premium library of tennis-specific mobility and recovery flows for better rotation, shoulder freedom, hip mobility, and match-day recovery.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !session.isPremiumUnlocked {
                Text("Unlock premium later to save these routines and access guided recovery support.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
