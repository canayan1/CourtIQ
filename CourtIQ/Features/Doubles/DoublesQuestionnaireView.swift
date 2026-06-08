import SwiftUI

/// Single-device doubles questionnaire (9 questions: 6 tactical + 3
/// chemistry). The hand-off between the two players is explicit, nothing
/// is pre-selected, and Next/See-result stay disabled until every question
/// is answered — so a result can't be computed against blank answers.
struct DoublesQuestionnaireView: View {
    @EnvironmentObject private var lang: LanguageManager

    private enum Step { case name, you, handoff, partner }

    @State private var step: Step = .name
    @State private var partnerName = ""
    @State private var me = DoublesDraft()
    @State private var partner = DoublesDraft()
    @State private var pushResult: DoublesPartnership?

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }
    private var trimmedName: String { partnerName.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch step {
                case .name:    nameStep
                case .you:     answersStep(forMe: true)
                case .handoff: handoffStep
                case .partner: answersStep(forMe: false)
                }
            }
            .padding()
        }
        .background(AppPalette.cream)
        .navigationTitle(headerTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $pushResult) { p in DoublesResultView(partnership: p) }
    }

    private var headerTitle: String {
        switch step {
        case .you:     return "1/2 · \(copy.youShort)"
        case .partner: return "2/2 · \(trimmedName.isEmpty ? copy.sectionTitle : trimmedName)"
        default:       return copy.newTestCTA
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(copy.partnerNamePrompt).font(.title3.bold()).foregroundStyle(AppPalette.ink)
            TextField(copy.partnerNamePlaceholder, text: $partnerName)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(AppPalette.parchment)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppPalette.sand, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            primaryButton(copy.next, enabled: !trimmedName.isEmpty) { step = .you }
        }
    }

    private var handoffStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 56)).foregroundStyle(AppPalette.clay).padding(.top, 24)
            Text(copy.handoffTitle(trimmedName))
                .font(.title3.bold()).multilineTextAlignment(.center).foregroundStyle(AppPalette.ink)
            Text(copy.handoffBody(trimmedName))
                .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            primaryButton(copy.handoffCTA(trimmedName), enabled: true) { step = .partner }
            secondaryButton(copy.back) { step = .you }
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 8)
    }

    @ViewBuilder
    private func answersStep(forMe: Bool) -> some View {
        let d = Binding<DoublesDraft>(get: { forMe ? me : partner },
                                      set: { if forMe { me = $0 } else { partner = $0 } })
        let complete = (forMe ? me : partner).isComplete
        VStack(alignment: .leading, spacing: 18) {
            whoBanner(forMe: forMe)

            DoublesAnswerForm(draft: d, copy: copy)

            HStack(spacing: 12) {
                secondaryButton(copy.back) { step = forMe ? .name : .handoff }
                if forMe {
                    primaryButton(copy.next, enabled: complete) { step = .handoff }
                } else {
                    primaryButton(copy.seeResult, enabled: complete) { finish() }
                }
            }
            .padding(.top, 4)
        }
    }

    private func whoBanner(forMe: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: forMe ? "person.fill" : "person.crop.circle.badge.checkmark")
                .foregroundStyle(AppPalette.clay)
            Text(forMe ? copy.answeringAsYou : copy.answeringAsPartner(trimmedName))
                .font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(AppPalette.clay.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func finish() {
        guard let myProfile = me.build(), let partnerProfile = partner.build() else { return }
        let p = DoublesPartnership(partnerName: trimmedName, myProfile: myProfile, partnerProfile: partnerProfile)
        DoublesStore.shared.save(p)
        pushResult = p
    }

    private func primaryButton(_ title: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent).tint(AppPalette.clay).disabled(!enabled)
    }

    private func secondaryButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).padding(.vertical, 14).padding(.horizontal, 18)
        }
        .buttonStyle(.bordered).tint(AppPalette.inkSoft)
    }
}
