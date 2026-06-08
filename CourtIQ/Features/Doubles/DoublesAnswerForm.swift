import SwiftUI

/// One player's in-progress answers to the 9-question doubles profile
/// (6 tactical + 3 chemistry). Shared by the single-device questionnaire,
/// the invite flow, and the join flow so all three collect identical data.
struct DoublesDraft {
    // tactical
    var side: DoublesSide?
    var net: NetComfort?
    var hand: Handedness?
    var formation: FormationComfort?
    var serve: Int?
    var ret: Int?
    // chemistry
    var comms: CommStyle?
    var temperament: Temperament?
    var goal: DoublesGoal?

    var isComplete: Bool {
        side != nil && net != nil && hand != nil && formation != nil &&
        serve != nil && ret != nil && comms != nil && temperament != nil && goal != nil
    }

    func build() -> DoublesProfile? {
        guard let side, let net, let hand, let formation, let serve, let ret,
              let comms, let temperament, let goal else { return nil }
        return DoublesProfile(preferredSide: side, netComfort: net, handedness: hand,
                              formation: formation, serveStrength: serve, returnStrength: ret,
                              comms: comms, temperament: temperament, goal: goal)
    }
}

/// The reusable 9-question form. Nothing is pre-selected; the parent gates its
/// "continue" action on `draft.isComplete`.
struct DoublesAnswerForm: View {
    @Binding var draft: DoublesDraft
    let copy: DoublesCopy

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeader(copy.sectionTacticalQ)
            choice(copy.prompt(.courtSide), selection: $draft.side, options: DoublesSide.allCases) { copy.sideOption($0) }
            choice(copy.prompt(.netBaseline), selection: $draft.net, options: NetComfort.allCases) { copy.netOption($0) }
            choice(copy.prompt(.handedness), selection: $draft.hand, options: Handedness.allCases) { copy.handOption($0) }
            choice(copy.prompt(.formation), selection: $draft.formation, options: FormationComfort.allCases) { copy.formationOption($0) }
            strengthRow(copy.serveStrengthLabel, $draft.serve)
            strengthRow(copy.returnStrengthLabel, $draft.ret)

            sectionHeader(copy.sectionChemistryQ)
            choice(copy.prompt(.comms), selection: $draft.comms, options: CommStyle.allCases) { copy.commsOption($0) }
            choice(copy.prompt(.temperament), selection: $draft.temperament, options: Temperament.allCases) { copy.temperamentOption($0) }
            choice(copy.prompt(.goal), selection: $draft.goal, options: DoublesGoal.allCases) { copy.goalOption($0) }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.heavy)).tracking(0.6)
            .foregroundStyle(AppPalette.inkSoft)
            .padding(.top, 6)
    }

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
}
