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
    @State private var selectedStrengths: Set<String>
    @State private var selectedWeaknesses: Set<String>

    /// Common tennis attributes, tap-selected as strengths / weaknesses. The
    /// English key is stored (stable across UI language + preferred by the AI
    /// compat grounding); chips display the localized label.
    static let attributeOptions: [(en: String, tr: String)] = [
        ("Serve", "Servis"), ("Second serve", "İkinci servis"),
        ("Forehand", "Forehand"), ("Backhand", "Backhand"),
        ("Return", "Return"), ("Net play", "File oyunu"),
        ("Movement", "Hareket"), ("Consistency", "İstikrar"),
        ("Power", "Güç"), ("Composure", "Soğukkanlılık"),
        ("Slice", "Slice"), ("Overhead", "Smaç")
    ]

    init(existing: DoublesPartner? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _level = State(initialValue: existing?.level)
        _handedness = State(initialValue: existing?.handedness)
        _style = State(initialValue: existing?.style)
        _selectedStrengths = State(initialValue: Self.seed(existing?.strengths))
        _selectedWeaknesses = State(initialValue: Self.seed(existing?.weaknesses))
    }

    /// Match a stored comma-list (saved in any UI language) back to English keys.
    private static func seed(_ raw: String?) -> Set<String> {
        guard let raw, !raw.isEmpty else { return [] }
        let tokens = Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
        var out = Set<String>()
        for opt in attributeOptions where tokens.contains(opt.en.lowercased()) || tokens.contains(opt.tr.lowercased()) {
            out.insert(opt.en)
        }
        return out
    }

    private static func serialize(_ set: Set<String>) -> String {
        attributeOptions.filter { set.contains($0.en) }.map(\.en).joined(separator: ", ")
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
                    attributeChips($selectedStrengths)
                }
                Section(copy.weaknessesLabel) {
                    attributeChips($selectedWeaknesses)
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

    /// Tap-to-toggle attribute chips (multi-select) — replaces free-text
    /// strengths / weaknesses so the whole partner profile is keyboard-free.
    private func attributeChips(_ selection: Binding<Set<String>>) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
            ForEach(Self.attributeOptions, id: \.en) { opt in
                let label = lang.language == .turkish ? opt.tr : opt.en
                let sel = selection.wrappedValue.contains(opt.en)
                Button {
                    Haptics.tap()
                    if sel { selection.wrappedValue.remove(opt.en) }
                    else { selection.wrappedValue.insert(opt.en) }
                } label: {
                    Text(label)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(sel ? .white : AppPalette.ink)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(sel ? AppPalette.clay : AppPalette.parchment, in: Capsule())
                        .overlay(Capsule().stroke(sel ? Color.clear : AppPalette.sand, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
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
            strengths: Self.serialize(selectedStrengths),
            weaknesses: Self.serialize(selectedWeaknesses)
        )
        store.save(partner)
        dismiss()
    }
}
