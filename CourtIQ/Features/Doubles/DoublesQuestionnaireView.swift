import SwiftUI

/// Single-device doubles questionnaire. Both players answer on the one
/// phone, so the flow makes the hand-off unmistakable:
///   name → YOU (1/2) → "pass the phone" → PARTNER (2/2) → result.
/// Nothing is pre-selected, and Next/See-result stay disabled until every
/// question is answered, so a result can never be computed against blank
/// (defaulted) partner answers.
struct DoublesQuestionnaireView: View {
    @EnvironmentObject private var lang: LanguageManager

    /// Per-player answers, all optional until tapped.
    private struct Draft {
        var side: DoublesSide?
        var net: NetComfort?
        var comms: CommStyle?
        var pressure: PressureStyle?
        var formation: FormationComfort?
        var hand: Handedness?
        var serve: Int?
        var ret: Int?
        var isComplete: Bool {
            side != nil && net != nil && comms != nil && pressure != nil &&
            formation != nil && hand != nil && serve != nil && ret != nil
        }
        func build() -> DoublesProfile? {
            guard let side, let net, let comms, let pressure,
                  let formation, let hand, let serve, let ret else { return nil }
            return DoublesProfile(preferredSide: side, netComfort: net, poach: .selective,
                                  comms: comms, pressure: pressure, formation: formation,
                                  handedness: hand, serveStrength: serve, returnStrength: ret)
        }
    }

    private enum Step { case name, you, handoff, partner }

    @State private var step: Step = .name
    @State private var partnerName = ""
    @State private var me = Draft()
    @State private var partner = Draft()
    @State private var pushResult: DoublesPartnership?

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }
    private var trimmedName: String { partnerName.trimmingCharacters(in: .whitespaces) }
    private var editingMe: Bool { step == .you }
    private var activeDraft: Draft { editingMe ? me : partner }

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
        .navigationDestination(item: $pushResult) { p in
            DoublesResultView(partnership: p)
        }
    }

    private var headerTitle: String {
        switch step {
        case .you:     return "1/2 · \(copy.youShort)"
        case .partner: return "2/2 · \(trimmedName.isEmpty ? copy.sectionTitle : trimmedName)"
        default:       return copy.newTestCTA
        }
    }

    // MARK: Name
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

    // MARK: Hand-off interstitial
    private var handoffStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AppPalette.clay)
                .padding(.top, 24)
            Text(copy.handoffTitle(trimmedName))
                .font(.title3.bold()).multilineTextAlignment(.center).foregroundStyle(AppPalette.ink)
            Text(copy.handoffBody(trimmedName))
                .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(AppPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            primaryButton(copy.handoffCTA(trimmedName), enabled: true) { step = .partner }
            secondaryButton(copy.back) { step = .you }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    // MARK: Answers (you / partner)
    @ViewBuilder
    private func answersStep(forMe: Bool) -> some View {
        let d = Binding<Draft>(
            get: { forMe ? me : partner },
            set: { if forMe { me = $0 } else { partner = $0 } }
        )
        VStack(alignment: .leading, spacing: 18) {
            whoBanner(forMe: forMe)
            choice(copy.prompt(.courtSide), selection: d.side, options: DoublesSide.allCases) { copy.sideOption($0) }
            choice(copy.prompt(.netBaseline), selection: d.net, options: NetComfort.allCases) { copy.netOption($0) }
            choice(copy.prompt(.comms), selection: d.comms, options: CommStyle.allCases) { copy.commsOption($0) }
            choice(copy.prompt(.pressure), selection: d.pressure, options: PressureStyle.allCases) { copy.pressureOption($0) }
            choice(copy.prompt(.formation), selection: d.formation, options: FormationComfort.allCases) { copy.formationOption($0) }
            choice(copy.prompt(.handedness), selection: d.hand, options: Handedness.allCases) { copy.handOption($0) }
            strengthRow(copy.serveStrengthLabel, d.serve)
            strengthRow(copy.returnStrengthLabel, d.ret)

            HStack(spacing: 12) {
                secondaryButton(copy.back) { step = forMe ? .name : .handoff }
                if forMe {
                    primaryButton(copy.next, enabled: me.isComplete) { step = .handoff }
                } else {
                    primaryButton(copy.seeResult, enabled: partner.isComplete) { finish() }
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

    // MARK: Reusable controls (optional selection — nothing pre-selected)
    @ViewBuilder
    private func choice<T: Hashable>(_ prompt: String, selection: Binding<T?>,
                                     options: [T], label: @escaping (T) -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(prompt).font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
            ForEach(options, id: \.self) { opt in
                let sel = selection.wrappedValue == opt
                Button { selection.wrappedValue = opt } label: {
                    HStack {
                        Text(label(opt)).font(.subheadline)
                        Spacer()
                        if sel { Image(systemName: "checkmark").font(.subheadline.bold()) }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(sel ? AppPalette.clay.opacity(0.14) : AppPalette.parchment)
                    .foregroundStyle(sel ? AppPalette.clay : AppPalette.ink)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(sel ? AppPalette.clay : AppPalette.sand, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func strengthRow(_ title: String, _ value: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppPalette.ink)
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { n in
                    let sel = value.wrappedValue == n
                    Button { value.wrappedValue = n } label: {
                        Text("\(n)")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(sel ? AppPalette.clay : AppPalette.parchment)
                            .foregroundStyle(sel ? .white : AppPalette.ink)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(sel ? AppPalette.clay : AppPalette.sand, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack { Text(copy.scaleWeak); Spacer(); Text(copy.scaleStrong) }
                .font(.caption2).foregroundStyle(AppPalette.inkSoft)
        }
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
