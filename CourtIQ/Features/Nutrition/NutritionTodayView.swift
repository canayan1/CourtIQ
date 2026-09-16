import SwiftUI

/// "What should I eat today?" — four taps, one card. The card is composed
/// from the guide's text for the player's answers; nothing is generated,
/// so the same four answers always give the same advice and every line
/// traces to a sourced section of the guide.
struct NutritionTodayView: View {
    let guide: NutritionGuide

    @EnvironmentObject private var lang: LanguageManager
    @ObservedObject private var manager = NutritionManager.shared

    // Remembered between visits. A player's court, climate and usual
    // intensity barely change week to week, so starting from scratch every
    // time was four taps charged for nothing. Stored as raw values because
    // AppStorage cannot hold these enums directly.
    @AppStorage("CourtIQ.Nutrition.Today.Hours")     private var hoursRaw = NutritionHoursUntil.h1to2.rawValue
    @AppStorage("CourtIQ.Nutrition.Today.Intensity") private var intensityRaw = NutritionIntensity.normal.rawValue
    @AppStorage("CourtIQ.Nutrition.Today.Heat")      private var heatRaw = NutritionHeat.warm.rawValue

    private var hours: NutritionHoursUntil { NutritionHoursUntil(rawValue: hoursRaw) ?? .h1to2 }
    private var intensity: NutritionIntensity { NutritionIntensity(rawValue: intensityRaw) ?? .normal }
    private var heat: NutritionHeat { NutritionHeat(rawValue: heatRaw) ?? .warm }

    /// "How did you feel last time?" is the one answer the fuel log already
    /// holds, so it is read rather than asked — and only asked when there is
    /// nothing to read.
    @State private var lastOverride: NutritionLastSession?
    private var last: NutritionLastSession { lastOverride ?? manager.lastSessionFeel ?? .ok }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                question(lang.t("nutrition.today_q_hours")) {
                    picker(NutritionHoursUntil.allCases, selected: hours) { hoursRaw = $0.rawValue }
                }
                question(lang.t("nutrition.today_q_intensity")) {
                    picker(NutritionIntensity.allCases, selected: intensity) { intensityRaw = $0.rawValue }
                }
                question(lang.t("nutrition.today_q_heat")) {
                    picker(NutritionHeat.allCases, selected: heat) { heatRaw = $0.rawValue }
                }
                question(lang.t("nutrition.today_q_last")) {
                    VStack(alignment: .leading, spacing: 8) {
                        picker(NutritionLastSession.allCases, selected: last) { lastOverride = $0 }
                        // Say where the answer came from, so a pre-filled chip
                        // does not look like the app guessing.
                        if lastOverride == nil, manager.lastSessionFeel != nil {
                            Text(lang.t("nutrition.today_last_from_log"))
                                .font(.caption)
                                .foregroundStyle(AppPalette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let advice = guide.advice(hours: hours, intensity: intensity, heat: heat, last: last) {
                    adviceCard(advice)
                }
                Text(lang.t("nutrition.disclaimer"))
                    .font(.caption)
                    .foregroundStyle(AppPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("nutrition.today_title"))
        .navigationBarTitleDisplayMode(.inline)
        .trackScreen("Nutrition Today")
    }

    private func question<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.ink)
            content()
        }
    }

    private func picker<T: Identifiable & Hashable & RawRepresentable>(_ options: [T], selected: T,
                                                                       pick: @escaping (T) -> Void) -> some View where T.RawValue == String {
        FlowLayout(spacing: 8) {
            ForEach(options) { option in
                let title = lang.t(labelKey(option))
                Button {
                    Haptics.tap()
                    pick(option)
                } label: {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(option == selected ? .white : AppPalette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(option == selected ? AppPalette.clay : AppPalette.parchment, in: Capsule())
                        .overlay(Capsule().stroke(option == selected ? AppPalette.clay : AppPalette.sand, lineWidth: 1))
                }
                .buttonStyle(PressableCardStyle())
            }
        }
    }

    private func labelKey<T: RawRepresentable>(_ option: T) -> String where T.RawValue == String {
        switch option {
        case let h as NutritionHoursUntil:   return h.labelKey
        case let i as NutritionIntensity:    return i.labelKey
        case let h as NutritionHeat:         return h.labelKey
        case let l as NutritionLastSession:  return l.labelKey
        default: return option.rawValue
        }
    }

    private func adviceCard(_ advice: NutritionTodayAdvice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(lang.t("nutrition.today_eyebrow"), tint: AppPalette.mossDeep)
            Text(advice.headline)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(AppPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            row("fork.knife", lang.t("nutrition.today_eat"), advice.eat)
            row("hand.raised", lang.t("nutrition.today_avoid"), advice.avoid)
            row("lightbulb", lang.t("nutrition.today_why"), advice.why)
            if !advice.extras.isEmpty {
                Divider().padding(.vertical, 2)
                ForEach(advice.extras, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                            .foregroundStyle(AppPalette.moss)
                            .padding(.top, 3)
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(AppPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(fill: AppPalette.mossTint.opacity(0.45), stroke: AppPalette.moss.opacity(0.35), cornerRadius: 18)
    }

    private func row(_ symbol: String, _ label: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(AppPalette.moss)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(AppPalette.inkSoft)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
