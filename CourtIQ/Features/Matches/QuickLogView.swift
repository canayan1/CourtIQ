import SwiftUI

/// 30-second post-match check-in. Four icon-led rating rows (serve,
/// return, movement, mental) + one short takeaway field + save. No
/// instructions, no helper paragraphs — the icons carry the meaning.
///
/// Design budget: under 30 words of UI text on the entire screen.
struct QuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var matches: MatchEntryManager
    @EnvironmentObject private var lang: LanguageManager

    @State private var serve: Int = 3
    @State private var ret: Int = 3
    @State private var movement: Int = 3
    @State private var mental: Int = 3
    @State private var result: MatchResult = .won
    @State private var surface: MatchSurface = .hard
    @State private var takeaway: String = ""
    @FocusState private var takeawayFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                resultAndSurface
                ratingsBlock
                takeawayField
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("matches.quick_log"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(lang.t("common.cancel")) { dismiss() }
                    .foregroundStyle(AppPalette.inkSoft)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(lang.t("common.save")) { save() }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(lang.t("common.done")) { takeawayFocused = false }
            }
        }
    }

    // MARK: - Result + surface row (icon-led, no labels)

    private var resultAndSurface: some View {
        HStack(spacing: 14) {
            resultSegment
            surfaceSegment
        }
    }

    private var resultSegment: some View {
        HStack(spacing: 0) {
            resultButton(value: .won,  label: "W", color: AppPalette.moss)
            resultButton(value: .lost, label: "L", color: AppPalette.alert)
        }
        .padding(4)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func resultButton(value: MatchResult, label: String, color: Color) -> some View {
        Button {
            Haptics.tap()
            result = value
        } label: {
            Text(label)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(result == value ? .white : AppPalette.inkSoft)
                .frame(width: 48, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(result == value ? color : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var surfaceSegment: some View {
        HStack(spacing: 6) {
            ForEach(MatchSurface.allCases) { s in
                surfaceTile(s)
            }
        }
    }

    private func surfaceTile(_ s: MatchSurface) -> some View {
        Button {
            Haptics.tap()
            surface = s
        } label: {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(surfaceColor(s))
                .frame(width: 44, height: 48)
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

    private func surfaceColor(_ s: MatchSurface) -> Color {
        switch s {
        case .clay:  return AppPalette.CourtSurface.clay.base
        case .grass: return AppPalette.CourtSurface.grass.base
        case .hard:  return AppPalette.CourtSurface.hard.base
        }
    }

    // MARK: - Ratings block

    private var ratingsBlock: some View {
        VStack(spacing: 14) {
            ratingRow(glyph: .serve,    value: $serve)
            ratingRow(glyph: .backhand, value: $ret)
            ratingRow(glyph: .mobility, value: $movement)
            ratingRow(glyph: .target,   value: $mental)
        }
        .padding(18)
        .background(AppPalette.parchment)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppPalette.sand, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func ratingRow(glyph: TennisGlyphKind, value: Binding<Int>) -> some View {
        HStack(spacing: 14) {
            TennisGlyph(kind: glyph, color: AppPalette.ink, size: 26)
                .frame(width: 30)

            HStack(spacing: 10) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Takeaway

    private var takeawayField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(AppPalette.clay)
                    .font(.subheadline.weight(.bold))
                Text(lang.t("matches.takeaway_label"))
                    .font(.caption.weight(.heavy))
                    .tracking(0.6)
                    .foregroundStyle(AppPalette.inkSoft)
                    .textCase(.uppercase)
            }

            TextField(
                lang.t("matches.takeaway_placeholder"),
                text: $takeaway,
                axis: .vertical
            )
            .lineLimit(2, reservesSpace: true)
            .focused($takeawayFocused)
            .font(.subheadline)
            .padding(14)
            .background(AppPalette.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppPalette.sand, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onChange(of: takeaway) { _, newValue in
                if newValue.count > 200 {
                    takeaway = String(newValue.prefix(200))
                }
            }
        }
    }

    // MARK: - Save

    private func save() {
        let entry = MatchEntry(
            opponentName: "",
            surface: surface,
            result: result,
            score: "",
            serveRating: serve,
            returnRating: ret,
            movementRating: movement,
            mentalRating: mental,
            preMatchNotes: "",
            postMatchNotes: "",
            takeaway: takeaway.trimmingCharacters(in: .whitespacesAndNewlines),
            isQuickLog: true
        )
        matches.save(entry)
        Haptics.confirm()
        dismiss()
    }
}
