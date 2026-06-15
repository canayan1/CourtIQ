import SwiftUI

/// Mobility & Recovery library, brought up to the DesignSystem bar (Phase 2 /
/// Wave 2): an `Eyebrow` section header per flow type, pressable cards
/// (`PressableCardStyle`) with a staggered `Motion.entrance` reveal, and rows
/// trimmed to icon + short title + a 1–2 word meta. The long goal / coaching
/// sentences now live only in `MobilityFlowDetailView`. All flows + premium
/// behavior are preserved.
struct MobilityLibraryView: View {
    @EnvironmentObject private var session: UserSessionManager
    @EnvironmentObject private var lang: LanguageManager

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let flows = MobilityFlow.sampleFlows

    @State private var appeared = false

    private var previewFlowIDs: Set<String> {
        Set(flows.prefix(2).map(\.id))
    }

    /// SF Symbol per flow type, matching the icon language used elsewhere.
    private func icon(for type: MobilityFlowType) -> String {
        switch type {
        case .quickReset:   return "bolt.heart"
        case .dailyMobility: return "figure.cooldown"
        case .recovery:     return "figure.walk"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                ForEach(Array(MobilityFlowType.allCases.enumerated()), id: \.element.id) { typeIndex, type in
                    let typeFlows = flows.filter { $0.type == type }
                    if !typeFlows.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Eyebrow(type.title)

                            ForEach(Array(typeFlows.enumerated()), id: \.element.id) { flowIndex, flow in
                                NavigationLink {
                                    MobilityFlowDetailView(flow: flow)
                                } label: {
                                    flowRow(flow)
                                }
                                .buttonStyle(PressableCardStyle())
                                .reveal(appeared: appeared,
                                        index: typeIndex + flowIndex,
                                        reduceMotion: reduceMotion)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(lang.t("mobility.library"))
        .background(AppPalette.cream)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else if !appeared {
                withAnimation(Motion.entrance) { appeared = true }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(lang.t("mobility.title"))
            Text(lang.t("mobility.headline"))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Flow row

    /// Trimmed row: type icon + short title + a 1–2 word meta (duration). The
    /// long goal/coaching copy is intentionally pushed into the detail view.
    private func flowRow(_ flow: MobilityFlow) -> some View {
        let isLocked = !session.isPremiumUnlocked && !previewFlowIDs.contains(flow.id)

        return HStack(spacing: 14) {
            Image(systemName: icon(for: flow.type))
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .frame(width: 30)

            Text(flow.localizedTitle(for: lang.language))
                .font(.headline)
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            } else {
                Text(flow.duration)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        // Flow row on a duotone mobility photo; foreground flips to white so the
        // title + duration + lock read over the scrim.
        .brandedPhoto("PhotoMobility", scrim: .bottom, cornerRadius: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(flow.localizedTitle(for: lang.language))
        .accessibilityValue(isLocked ? lang.t("mobility.premium") : flow.duration)
    }
}

// MARK: - Staggered entrance modifier

private extension View {
    /// Mirrors the Train hub's tactile staggered entrance; Reduce-Motion safe.
    @ViewBuilder
    func reveal(appeared: Bool, index: Int, reduceMotion: Bool) -> some View {
        if reduceMotion {
            self.opacity(appeared ? 1 : 0)
        } else {
            self
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
                .scaleEffect(appeared ? 1 : 0.97)
                .animation(Motion.entrance.delay(Double(index) * Motion.stagger),
                           value: appeared)
        }
    }
}
