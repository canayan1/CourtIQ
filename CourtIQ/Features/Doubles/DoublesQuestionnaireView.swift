import SwiftUI

/// Single-device doubles questionnaire: name the partner, fill your 8
/// answers, hand the phone over for the partner's 8 answers, then see the
/// result. (On-court QR pairing + remote invite come in later steps.)
struct DoublesQuestionnaireView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0            // 0 = name, 1 = you, 2 = partner
    @State private var partnerName = ""
    @State private var me = DoublesProfile.unset
    @State private var partner = DoublesProfile.unset
    @State private var pushResult: DoublesPartnership?

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }
    private var active: Binding<DoublesProfile> { step == 1 ? $me : $partner }
    private var trimmedName: String { partnerName.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if step == 0 { nameStep } else { answersStep }
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
        case 1: return copy.youHeader
        case 2: return copy.partnerHeader(trimmedName.isEmpty ? copy.sectionTitle : trimmedName)
        default: return copy.newTestCTA
        }
    }

    // MARK: Name step
    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(copy.partnerNamePrompt).font(.title3.bold()).foregroundStyle(AppPalette.ink)
            TextField(copy.partnerNamePlaceholder, text: $partnerName)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(AppPalette.parchment)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppPalette.sand, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            primaryButton(copy.next, enabled: !trimmedName.isEmpty) { step = 1 }
        }
    }

    // MARK: Answers step (you / partner)
    private var answersStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            choice(copy.prompt(.courtSide), selection: active.preferredSide,
                   options: DoublesSide.allCases) { copy.sideOption($0) }
            choice(copy.prompt(.netBaseline), selection: active.netComfort,
                   options: NetComfort.allCases) { copy.netOption($0) }
            choice(copy.prompt(.comms), selection: active.comms,
                   options: CommStyle.allCases) { copy.commsOption($0) }
            choice(copy.prompt(.pressure), selection: active.pressure,
                   options: PressureStyle.allCases) { copy.pressureOption($0) }
            choice(copy.prompt(.formation), selection: active.formation,
                   options: FormationComfort.allCases) { copy.formationOption($0) }
            choice(copy.prompt(.handedness), selection: active.handedness,
                   options: Handedness.allCases) { copy.handOption($0) }
            strengthRow(copy.serveStrengthLabel, active.serveStrength)
            strengthRow(copy.returnStrengthLabel, active.returnStrength)

            HStack(spacing: 12) {
                secondaryButton(copy.back) { step -= 1 }
                if step == 1 {
                    primaryButton(copy.next, enabled: true) { step = 2 }
                } else {
                    primaryButton(copy.seeResult, enabled: true) { finish() }
                }
            }
            .padding(.top, 4)
        }
    }

    private func finish() {
        let p = DoublesPartnership(partnerName: trimmedName, myProfile: me, partnerProfile: partner)
        DoublesStore.shared.save(p)
        pushResult = p
    }

    // MARK: Reusable controls
    @ViewBuilder
    private func choice<T: Hashable>(_ prompt: String, selection: Binding<T>,
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

    private func strengthRow(_ title: String, _ value: Binding<Int>) -> some View {
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
            HStack {
                Text(copy.scaleWeak); Spacer(); Text(copy.scaleStrong)
            }
            .font(.caption2).foregroundStyle(AppPalette.inkSoft)
        }
    }

    private func primaryButton(_ title: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(AppPalette.clay)
        .disabled(!enabled)
    }

    private func secondaryButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).padding(.vertical, 14).padding(.horizontal, 18)
        }
        .buttonStyle(.bordered)
        .tint(AppPalette.inkSoft)
    }
}
