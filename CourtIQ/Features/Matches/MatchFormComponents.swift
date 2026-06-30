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
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
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
                        .font(.system(size: 13, weight: .bold, design: .rounded))
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
}
