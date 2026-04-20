import SwiftUI

struct MobilityLibraryView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager
    private let flows = MobilityFlow.sampleFlows

    private var previewFlowIDs: Set<String> {
        Set(flows.prefix(2).map(\.id))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                premiumHeader

                ForEach(MobilityFlowType.allCases) { type in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(type.title)
                            .font(.title3.bold())

                        ForEach(flows.filter { $0.type == type }) { flow in
                            NavigationLink {
                                MobilityFlowDetailView(flow: flow)
                            } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(flow.localizedTitle(for: lang.language))
                                                .font(.headline)
                                            if !session.isPremiumUnlocked && !previewFlowIDs.contains(flow.id) {
                                                Image(systemName: "lock.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(AppPalette.inkSoft)
                                            }
                                        }
                                        Text(flow.localizedGoal(for: lang.language))
                                            .font(.subheadline)
                                            .foregroundStyle(AppPalette.inkSoft)

                                        HStack(spacing: 10) {
                                            Label(flow.duration, systemImage: "timer")
                                            Label(flow.focusLabel, systemImage: "target")
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppPalette.inkSoft)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding()
                                .background(AppPalette.parchment)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(AppPalette.sand, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(lang.t("mobility.library"))
        .background(AppPalette.cream)
    }

    private var premiumHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(lang.t("mobility.title"))
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(session.premiumStatus.title)
                    .font(.caption.weight(.semibold))
                    .padding(6)
                    .background((session.isPremiumUnlocked ? AppPalette.moss : AppPalette.clay).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Text(lang.t("mobility.preview_desc"))
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
        }
        .padding()
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
