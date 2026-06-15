import SwiftUI

/// Add / edit a doubles partner mini-profile: name (required), level, handedness,
/// style, strengths, weaknesses. Reuses the Tennis Profile level + archetype
/// enums and `SwingHandedness`. On save, writes through `DoublesStore` and
/// dismisses.
struct DoublesPartnerFormView: View {
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var store = DoublesStore.shared

    /// The partner being edited, or nil for a brand-new one.
    let existing: DoublesPartner?

    private var copy: DoublesCopy { DoublesCopy(lang: lang.language) }

    @State private var name: String
    @State private var level: TennisLevel?
    @State private var handedness: SwingHandedness?
    @State private var style: TennisArchetype?
    @State private var strengths: String
    @State private var weaknesses: String

    init(existing: DoublesPartner? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _level = State(initialValue: existing?.level)
        _handedness = State(initialValue: existing?.handedness)
        _style = State(initialValue: existing?.style)
        _strengths = State(initialValue: existing?.strengths ?? "")
        _weaknesses = State(initialValue: existing?.weaknesses ?? "")
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // The archetypes worth offering in the partner picker (all five).
    private let styleOptions: [TennisArchetype] = [
        .developing, .aggressiveBaseliner, .counterpuncher, .allCourt, .serveVolleyer
    ]

    var body: some View {
        ZStack {
            AppPalette.cream.ignoresSafeArea()
            Form {
                Section(copy.nameLabel) {
                    TextField(copy.namePlaceholder, text: $name)
                }

                Section(copy.levelLabel) {
                    Picker(copy.levelLabel, selection: $level) {
                        Text(copy.notSet).tag(TennisLevel?.none)
                        ForEach(TennisLevel.allCases, id: \.self) { l in
                            Text(copy.level(l)).tag(TennisLevel?.some(l))
                        }
                    }
                }

                Section(copy.handednessLabel) {
                    Picker(copy.handednessLabel, selection: $handedness) {
                        Text(copy.notSet).tag(SwingHandedness?.none)
                        ForEach(SwingHandedness.allCases) { h in
                            Text(copy.handedness(h)).tag(SwingHandedness?.some(h))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(copy.styleLabel) {
                    Picker(copy.styleLabel, selection: $style) {
                        Text(copy.notSet).tag(TennisArchetype?.none)
                        ForEach(styleOptions, id: \.self) { a in
                            Text(copy.style(a)).tag(TennisArchetype?.some(a))
                        }
                    }
                }

                Section(copy.strengthsLabel) {
                    TextField(copy.strengthsPlaceholder, text: $strengths, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section(copy.weaknessesLabel) {
                    TextField(copy.weaknessesPlaceholder, text: $weaknesses, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(existing == nil ? copy.newPartnerTitle : copy.editPartnerTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(copy.saveCTA) { save() }
                    .disabled(!canSave)
                    .tint(AppPalette.clay)
            }
        }
    }

    private func save() {
        // `TennisLevel` is Int-backed; persist its rawValue as a String so the
        // model can round-trip it without leaking the enum's backing type.
        let partner = DoublesPartner(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            levelRaw: level.map { String($0.rawValue) },
            handednessRaw: handedness?.rawValue,
            styleRaw: style?.rawValue,
            strengths: strengths.trimmingCharacters(in: .whitespacesAndNewlines),
            weaknesses: weaknesses.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        store.save(partner)
        dismiss()
    }
}
