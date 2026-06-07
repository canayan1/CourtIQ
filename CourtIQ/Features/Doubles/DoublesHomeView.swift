import SwiftUI

/// Doubles section entry: start a new compatibility test or revisit saved
/// partnerships. Pushed from a prominent card on the Today hub (the tab
/// bar is full at 5; final placement decided after dogfooding).
struct DoublesHomeView: View {
    @EnvironmentObject private var lang: LanguageManager
    @ObservedObject private var store = DoublesStore.shared

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                NavigationLink {
                    DoublesQuestionnaireView()
                } label: {
                    Label(copy.newTestCTA, systemImage: "person.2.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(AppPalette.clay)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                if store.partnerships.isEmpty {
                    emptyState
                } else {
                    partnershipsList
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(copy.sectionTitle)
        .navigationBarTitleDisplayMode(.large)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(copy.homeTitle).font(.title2.bold()).foregroundStyle(AppPalette.ink)
            Text(copy.homeSubtitle).font(.subheadline).foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.emptyTitle).font(.headline).foregroundStyle(AppPalette.ink)
            Text(copy.emptyBody).font(.subheadline).foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var partnershipsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.partnershipsHeader).font(.headline).foregroundStyle(AppPalette.ink)
            ForEach(store.partnerships) { p in
                NavigationLink {
                    DoublesResultView(partnership: p)
                } label: {
                    partnershipRow(p)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func partnershipRow(_ p: DoublesPartnership) -> some View {
        let score = p.result.score
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(AppPalette.clay.opacity(0.14)).frame(width: 46, height: 46)
                Text("\(score)").font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(AppPalette.clay)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(copy.youShort) & \(p.partnerName)")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
                Text(copy.testedOn(Self.dateFmt.string(from: p.createdAt)))
                    .font(.caption).foregroundStyle(AppPalette.inkSoft)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button(role: .destructive) { store.delete(p) } label: {
                Label(copy.deletePartnership, systemImage: "trash")
            }
        }
    }
}
