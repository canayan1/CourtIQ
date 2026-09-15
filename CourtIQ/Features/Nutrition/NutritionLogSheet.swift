import SwiftUI

/// The pre-session log: five taps and an optional note. Single-choice chips
/// throughout so every answer lands in a bucket the insights can count.
struct NutritionLogSheet: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = NutritionManager.shared

    @State private var kind: NutritionSessionKind = .practice
    @State private var timing: NutritionTiming = .h1to2
    @State private var meal: NutritionMealType = .balanced
    @State private var hydration: NutritionHydration = .ok
    @State private var caffeine = false
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    question(lang.t("nutrition.q_kind")) {
                        chips(NutritionSessionKind.allCases, selected: kind) { kind = $0 }
                    }
                    question(lang.t("nutrition.q_timing")) {
                        chips(NutritionTiming.allCases, selected: timing) { timing = $0 }
                    }
                    if timing != .nothing {
                        question(lang.t("nutrition.q_meal")) {
                            chips(NutritionMealType.allCases, selected: meal) { meal = $0 }
                        }
                    }
                    question(lang.t("nutrition.q_hydration")) {
                        chips(NutritionHydration.allCases, selected: hydration) { hydration = $0 }
                    }
                    question(lang.t("nutrition.q_caffeine")) {
                        HStack(spacing: 8) {
                            chip(lang.t("nutrition.caffeine_yes"), selected: caffeine) { caffeine = true }
                            chip(lang.t("nutrition.caffeine_no"), selected: !caffeine) { caffeine = false }
                        }
                    }
                    TextField(lang.t("nutrition.note_placeholder"), text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(AppPalette.parchment, in: RoundedRectangle(cornerRadius: 12))
                    PrimaryButton(title: lang.t("nutrition.save"), icon: "checkmark") {
                        manager.log(kind: kind, timing: timing, meal: meal,
                                    hydration: hydration, caffeine: caffeine, note: note)
                        Haptics.success()
                        dismiss()
                    }
                }
                .padding(20)
            }
            .background(AppPalette.cream)
            .navigationTitle(lang.t("nutrition.log_cta"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func question<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
            content()
        }
    }

    private func chips<T: Identifiable & Hashable>(_ options: [T], selected: T, label: ((T) -> String)? = nil,
                                                   pick: @escaping (T) -> Void) -> some View where T: RawRepresentable, T.RawValue == String {
        FlowLayout(spacing: 8) {
            ForEach(options) { option in
                chip(lang.t(labelKey(option)), selected: option == selected) { pick(option) }
            }
        }
    }

    private func labelKey<T: RawRepresentable>(_ option: T) -> String where T.RawValue == String {
        switch option {
        case let k as NutritionSessionKind: return k.labelKey
        case let t as NutritionTiming:      return t.labelKey
        case let m as NutritionMealType:    return m.labelKey
        case let h as NutritionHydration:   return h.labelKey
        default: return option.rawValue
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? .white : AppPalette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(selected ? AppPalette.clay : AppPalette.parchment, in: Capsule())
                .overlay(Capsule().stroke(selected ? AppPalette.clay : AppPalette.sand, lineWidth: 1))
        }
        .buttonStyle(PressableCardStyle())
    }
}
