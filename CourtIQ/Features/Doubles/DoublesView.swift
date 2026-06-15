import SwiftUI

/// The Doubles Compatibility home: a list of saved partners (name + latest
/// compatibility score badge) with an "Add partner" button, and an empty state.
/// Tapping a partner opens its detail screen. Entry point is the Today card.
struct DoublesView: View {
    @EnvironmentObject private var lang: LanguageManager
    @StateObject private var store = DoublesStore.shared

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }

    @State private var showAddPartner = false

    private var inviteCopy: DoublesInviteCopy { DoublesInviteCopy(lang: lang.language) }

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // The viral invite loop — pair up with a real partner.
                    DoublesInviteSection()

                    // Secondary path: the existing solo "analyze a partner
                    // manually" flow, kept fully intact below the invite loop.
                    manualSection
                }
                .padding(20)
            }
        }
        .navigationTitle(copy.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        // The invite loop is the hero; the manual "Add partner" affordance lives
        // inside the secondary manual section below. A duplicate toolbar "+"
        // (also opening DoublesPartnerFormView) was redundant and removed.
        .navigationDestination(isPresented: $showAddPartner) {
            DoublesPartnerFormView()
        }
    }

    /// The existing manual ("quick read") flow, embedded below the invite loop
    /// as the clearly SECONDARY path. A divider + softer header set it apart
    /// from the invite hero above.
    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(AppPalette.sand)
                .padding(.bottom, 2)

            HStack(alignment: .firstTextBaseline) {
                Text(inviteCopy.manualHeader)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button {
                    showAddPartner = true
                } label: {
                    Label(copy.addPartnerCTA, systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(AppPalette.clay)
            }

            if store.partners.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.partners) { partner in
                        NavigationLink {
                            DoublesPartnerDetailView(partnerId: partner.id)
                        } label: {
                            row(partner)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func row(_ partner: DoublesPartner) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(AppPalette.moss.opacity(0.16)).frame(width: 46, height: 46)
                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(AppPalette.moss)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(partner.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                if let level = partner.level {
                    Text(copy.level(level))
                        .font(.caption)
                        .foregroundStyle(AppPalette.inkSoft)
                }
            }

            Spacer(minLength: 0)

            if let score = store.latestScore(forPartner: partner.id) {
                DoublesScoreBadge(score: score, copy: copy)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyState: some View {
        Text(copy.listEmpty)
            .font(.subheadline)
            .foregroundStyle(AppPalette.inkSoft)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}
