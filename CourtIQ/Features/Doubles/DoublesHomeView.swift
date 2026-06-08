import SwiftUI

/// Doubles section entry: start a new compatibility test or revisit saved
/// partnerships. Pushed from a prominent card on the Today hub (the tab
/// bar is full at 5; final placement decided after dogfooding).
struct DoublesHomeView: View {
    @EnvironmentObject private var lang: LanguageManager
    @EnvironmentObject private var session: UserSessionManager
    @ObservedObject private var store = DoublesStore.shared
    @ObservedObject private var service = DoublesService.shared

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none; return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                actionButtons
                if !service.partnerships.isEmpty { serverPartnershipsList }
                if !store.partnerships.isEmpty { partnershipsList }
                if service.partnerships.isEmpty && store.partnerships.isEmpty { emptyState }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(copy.sectionTitle)
        .navigationBarTitleDisplayMode(.large)
        .task {
            service.configure { try await session.ensureAnonymousSession() }
            await service.loadPartnerships()
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            NavigationLink { DoublesInviteView() } label: {
                actionLabel(copy.inviteCTA, "paperplane.fill", primary: true)
            }.buttonStyle(.plain)
            NavigationLink { DoublesJoinView() } label: {
                actionLabel(copy.joinCTA, "qrcode.viewfinder", primary: false)
            }.buttonStyle(.plain)
            NavigationLink { DoublesQuestionnaireView() } label: {
                Text(copy.singleDeviceCTA)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.inkSoft)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            }.buttonStyle(.plain)
        }
    }

    private func actionLabel(_ title: String, _ icon: String, primary: Bool) -> some View {
        Label(title, systemImage: icon)
            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(primary ? AppPalette.clay : AppPalette.parchment)
            .foregroundStyle(primary ? .white : AppPalette.ink)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(primary ? Color.clear : AppPalette.sand, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var serverPartnershipsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.serverPartnershipsHeader).font(.headline).foregroundStyle(AppPalette.ink)
            ForEach(service.partnerships) { row in serverRow(row) }
        }
    }

    @ViewBuilder
    private func serverRow(_ row: DoublesPartnershipRow) -> some View {
        let uid = service.currentUserID ?? ""
        if let p = row.viewerPartnership(userID: uid) {
            NavigationLink { DoublesResultView(partnership: p) } label: {
                serverRowContent(row, score: p.result.score, pending: false)
            }
            .buttonStyle(.plain)
        } else {
            serverRowContent(row, score: nil, pending: true)
        }
    }

    private func serverRowContent(_ row: DoublesPartnershipRow, score: Int?, pending: Bool) -> some View {
        let uid = service.currentUserID ?? ""
        let otherName = (row.viewerIsInviter(uid) ? row.inviteeName : row.inviterName)?
            .trimmingCharacters(in: .whitespaces)
        let title = (otherName?.isEmpty == false) ? "\(copy.youShort) & \(otherName!)" : copy.pendingBadge
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill((pending ? AppPalette.inkSoft : AppPalette.clay).opacity(0.14)).frame(width: 46, height: 46)
                if let score {
                    Text("\(score)").font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(AppPalette.clay)
                } else {
                    Image(systemName: "hourglass").foregroundStyle(AppPalette.inkSoft)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
                Text(pending ? copy.pendingNote : copy.testedOn(Self.dateFmt.string(from: row.createdAt ?? Date())))
                    .font(.caption).foregroundStyle(AppPalette.inkSoft)
            }
            Spacer()
            if !pending { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
        }
        .padding(14)
        .background(AppPalette.parchment)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
            Button(role: .destructive) { Task { await service.deletePartnership(row) } } label: {
                Label(copy.deletePartnership, systemImage: "trash")
            }
        }
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
            Text(copy.localPartnershipsHeader).font(.headline).foregroundStyle(AppPalette.ink)
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
