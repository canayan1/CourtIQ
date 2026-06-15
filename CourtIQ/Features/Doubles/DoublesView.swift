import SwiftUI

/// The Doubles Compatibility home: a list of saved partners (name + latest
/// compatibility score badge) with an "Add partner" button, and an empty state.
/// Tapping a partner opens its detail screen. Entry point is the Today card.
struct DoublesView: View {
    @EnvironmentObject private var lang: LanguageManager
    @StateObject private var store = DoublesStore.shared

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }

    @State private var showAddPartner = false

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            if store.partners.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle(copy.navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddPartner = true
                } label: {
                    Label(copy.addPartnerCTA, systemImage: "plus")
                }
                .tint(AppPalette.clay)
            }
        }
        .navigationDestination(isPresented: $showAddPartner) {
            DoublesPartnerFormView()
        }
    }

    private var list: some View {
        ScrollView {
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
            .padding(20)
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
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppPalette.moss)
            Text(copy.listEmpty)
                .font(.subheadline)
                .foregroundStyle(AppPalette.inkSoft)
                .multilineTextAlignment(.center)
            Button {
                showAddPartner = true
            } label: {
                Label(copy.addPartnerCTA, systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.clay)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
