import SwiftUI

/// A partner's detail screen: their mini-profile info, a primary "Analyze our
/// pairing" CTA, the list of past compatibility reports (newest first, tap to
/// re-read), an edit affordance, and a delete that removes the partner + all of
/// its reports.
struct DoublesPartnerDetailView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var store = DoublesStore.shared

    let partnerId: UUID

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }

    @State private var showAnalysis = false
    @State private var showEdit = false
    @State private var showDeleteConfirm = false

    /// Always read the live partner from the store so edits reflect immediately.
    private var partner: DoublesPartner? { store.partner(withID: partnerId) }

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            if let partner {
                content(partner)
            } else {
                // Partner was deleted underneath us — bounce back.
                Color.clear.onAppear { dismiss() }
            }
        }
        .navigationTitle(partner?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if partner != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEdit = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .tint(AppPalette.clay)
                }
            }
        }
        .navigationDestination(isPresented: $showAnalysis) {
            if let partner {
                DoublesAnalysisView(partner: partner)
            }
        }
        .navigationDestination(isPresented: $showEdit) {
            if let partner {
                DoublesPartnerFormView(existing: partner)
            }
        }
        .alert(copy.deletePartnerCTA, isPresented: $showDeleteConfirm) {
            Button(copy.deleteCTA, role: .destructive) {
                store.deletePartner(partnerId)
                dismiss()
            }
            Button(copy.cancelCTA, role: .cancel) { }
        } message: {
            Text(copy.deletePartnerConfirm)
        }
    }

    @ViewBuilder
    private func content(_ partner: DoublesPartner) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                infoCard(partner)

                Button {
                    showAnalysis = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                        Text(copy.analyzeCTA)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)

                pastReports(partner)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(copy.deletePartnerCTA, systemImage: "trash")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    private func infoCard(_ partner: DoublesPartner) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let level = partner.level {
                infoRow(copy.levelLabel, copy.level(level))
            }
            if let handedness = partner.handedness {
                infoRow(copy.handednessLabel, copy.handedness(handedness))
            }
            if let style = partner.style {
                infoRow(copy.styleLabel, copy.style(style))
            }
            if !partner.strengths.isEmpty {
                infoRow(copy.strengthsLabel, partner.strengths)
            }
            if !partner.weaknesses.isEmpty {
                infoRow(copy.weaknessesLabel, partner.weaknesses)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.heavy))
                .tracking(0.4)
                .foregroundStyle(AppPalette.inkSoft)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func pastReports(_ partner: DoublesPartner) -> some View {
        let partnerReports = store.reports(forPartner: partner.id)
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.pastReportsHeader)
                .font(.headline)
                .foregroundStyle(AppPalette.ink)

            if partnerReports.isEmpty {
                Text(copy.noReportsYet)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(partnerReports) { report in
                    NavigationLink {
                        DoublesReportDetailView(report: report)
                    } label: {
                        reportRow(report)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reportRow(_ report: DoublesReport) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(copy.reportTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.ink)
                Text(copy.relativeDate(report.date))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
            }
            Spacer(minLength: 0)
            if let score = report.score {
                DoublesScoreBadge(score: score, copy: copy)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
