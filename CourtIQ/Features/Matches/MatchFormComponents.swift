import SwiftUI

/// Shared building blocks for the pre/post match forms so the upcoming
/// form, played form, and "add result" form all share one visual language
/// (matches the original MatchJournalEntryView styling).
enum MatchFormComponents {

    // MARK: - Surface picker

    struct SurfacePicker: View {
        @Binding var surface: MatchSurface

        var body: some View {
            HStack(spacing: 6) {
                ForEach(MatchSurface.allCases) { s in
                    Button {
                        Haptics.tap()
                        surface = s
                    } label: {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Self.color(s))
                            .frame(width: 40, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        surface == s ? AppPalette.ink : Color.clear,
                                        lineWidth: 2.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }

        static func color(_ s: MatchSurface) -> Color {
            switch s {
            case .clay:  return AppPalette.CourtSurface.clay.base
            case .grass: return AppPalette.CourtSurface.grass.base
            case .hard:  return AppPalette.CourtSurface.hard.base
            }
        }
    }

    // MARK: - Result picker (W / L)

    struct ResultPicker: View {
        @Binding var result: MatchResult

        var body: some View {
            HStack(spacing: 0) {
                button(value: .won,  label: "W", color: AppPalette.moss)
                button(value: .lost, label: "L", color: AppPalette.alert)
            }
            .padding(4)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }

        private func button(value: MatchResult, label: String, color: Color) -> some View {
            Button {
                Haptics.tap()
                result = value
            } label: {
                Text(label)
                    .appFont(16, weight: .heavy)
                    .foregroundStyle(result == value ? .white : AppPalette.inkSoft)
                    .frame(width: 40, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(result == value ? color : Color.clear)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Boxed text field

    struct BoxedField: View {
        let placeholder: String
        @Binding var text: String
        var monospaced: Bool = false

        var body: some View {
            TextField(placeholder, text: $text)
                .font(monospaced
                      ? .system(.subheadline, design: .monospaced).weight(.semibold)
                      : .system(size: 18, weight: .semibold, design: .rounded))
                .padding(12)
                .background(AppPalette.parchment)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppPalette.sand, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Labeled multi-line note

    struct NoteField: View {
        let iconName: String
        let iconColor: Color
        let label: String
        let placeholder: String
        @Binding var text: String
        var lineLimit: Int = 6

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: iconName)
                        .foregroundStyle(iconColor)
                        .font(.subheadline.weight(.bold))
                    Text(label)
                        .font(.caption.weight(.heavy))
                        .tracking(0.6)
                        .foregroundStyle(AppPalette.inkSoft)
                        .textCase(.uppercase)
                }
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(lineLimit, reservesSpace: true)
                    .font(.subheadline)
                    .padding(14)
                    .background(AppPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppPalette.sand, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: - Ratings block (serve / return / movement / mental, 1...5)

    struct RatingsBlock: View {
        @EnvironmentObject private var lang: LanguageManager
        @Binding var serve: Int
        @Binding var ret: Int
        @Binding var movement: Int
        @Binding var mental: Int

        var body: some View {
            VStack(spacing: 14) {
                row(glyph: .serve,    label: lang.t("matches.dim_serve"),    value: $serve)
                row(glyph: .backhand, label: lang.t("matches.dim_return"),   value: $ret)
                row(glyph: .mobility, label: lang.t("matches.dim_movement"), value: $movement)
                row(glyph: .target,   label: lang.t("matches.dim_mental"),   value: $mental)
            }
            .padding(18)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }

        private func row(glyph: TennisGlyphKind, label: String, value: Binding<Int>) -> some View {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    TennisGlyph(kind: glyph, color: AppPalette.ink, size: 22)
                        .frame(width: 26)
                    Text(label)
                        .appFont(13, weight: .bold)
                        .foregroundStyle(AppPalette.ink)
                }
                .frame(width: 110, alignment: .leading)

                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { dot in
                        Button {
                            Haptics.tap()
                            value.wrappedValue = dot
                        } label: {
                            Circle()
                                .fill(value.wrappedValue >= dot ? AppPalette.clay : AppPalette.sand)
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            value.wrappedValue == dot
                                                ? AppPalette.ink.opacity(0.5)
                                                : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label): \(value.wrappedValue)")
        }
    }

    // MARK: - Score builder (tap-based, no keyboard)

    /// Builds a scoreline ("6-4, 3-6, 7-5") entirely by tapping — a game
    /// stepper per side, per set, with the set winner tinted. Reads/writes the
    /// same free-text string the model already stores, so nothing downstream
    /// (display, AI summary) has to change.
    struct ScoreBuilder: View {
        @Binding var score: String
        @EnvironmentObject private var lang: LanguageManager

        struct SetScore: Identifiable, Equatable { let id = UUID(); var you = 0; var opp = 0 }

        @State private var sets: [SetScore] = [SetScore()]
        @State private var lastSerialized = ""

        private func t(_ en: String, _ tr: String) -> String { lang.language == .turkish ? tr : en }

        var body: some View {
            VStack(spacing: 10) {
                ForEach($sets) { $s in
                    setCard($s)
                }
                if sets.count < 5 {
                    Button {
                        Haptics.tap()
                        sets.append(SetScore())
                    } label: {
                        Label(t("Add set", "Set ekle"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppPalette.clay)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppPalette.clay.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .onChange(of: score, initial: true) { _, newValue in
                if newValue != lastSerialized { parse(newValue) }
            }
            .onChange(of: sets) { _, _ in serialize() }
        }

        private func setCard(_ s: Binding<SetScore>) -> some View {
            let you = s.wrappedValue.you, opp = s.wrappedValue.opp
            let idx = sets.firstIndex(where: { $0.id == s.wrappedValue.id }) ?? 0
            return VStack(spacing: 10) {
                HStack {
                    Text(t("Set \(idx + 1)", "\(idx + 1). set"))
                        .font(.caption.weight(.heavy)).tracking(0.6)
                        .foregroundStyle(AppPalette.inkSoft).textCase(.uppercase)
                    Spacer()
                    if sets.count > 1 {
                        Button {
                            Haptics.tap()
                            sets.removeAll { $0.id == s.wrappedValue.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppPalette.sand)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(spacing: 14) {
                    sideStepper(t("You", "Sen"), value: s.you, win: you > opp)
                    Text("–").font(.title3.weight(.bold)).foregroundStyle(AppPalette.sand)
                    sideStepper(t("Opp", "Rakip"), value: s.opp, win: opp > you)
                }
            }
            .padding(14)
            .background(AppPalette.parchment)
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppPalette.sand, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }

        private func sideStepper(_ label: String, value: Binding<Int>, win: Bool) -> some View {
            VStack(spacing: 6) {
                Text(label)
                    .font(.caption2.weight(.bold)).foregroundStyle(AppPalette.inkSoft).textCase(.uppercase)
                HStack(spacing: 10) {
                    stepButton("minus", enabled: value.wrappedValue > 0) {
                        value.wrappedValue = max(0, value.wrappedValue - 1)
                    }
                    Text("\(value.wrappedValue)")
                        .appFont(22, weight: .heavy)
                        .foregroundStyle(win ? AppPalette.moss : AppPalette.ink)
                        .frame(minWidth: 26)
                    stepButton("plus", enabled: value.wrappedValue < 7) {
                        value.wrappedValue = min(7, value.wrappedValue + 1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }

        private func stepButton(_ symbol: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
            Button {
                Haptics.tap()
                action()
            } label: {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(enabled ? .white : AppPalette.inkSoft.opacity(0.4))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(enabled ? AppPalette.clay : AppPalette.sand.opacity(0.5)))
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
        }

        // MARK: parse / serialize (free-text string is the source of truth)

        private func parse(_ raw: String) {
            let parsed: [SetScore] = raw
                .split(separator: ",")
                .compactMap { chunk in
                    let parts = chunk.split(whereSeparator: { $0 == "-" || $0 == "–" })
                    guard parts.count == 2,
                          let a = Int(parts[0].trimmingCharacters(in: .whitespaces)),
                          let b = Int(parts[1].trimmingCharacters(in: .whitespaces)) else { return nil }
                    return SetScore(you: min(7, max(0, a)), opp: min(7, max(0, b)))
                }
            sets = parsed.isEmpty ? [SetScore()] : parsed
        }

        private func serialize() {
            let built = sets
                .filter { $0.you > 0 || $0.opp > 0 }
                .map { "\($0.you)-\($0.opp)" }
                .joined(separator: ", ")
            lastSerialized = built
            if score != built { score = built }
        }
    }
}
