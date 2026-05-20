import SwiftUI

/// "Locker Room" — the avatar customization screen.
///
/// Big preview at the top, scrollable category picker below (Outfit /
/// Racket / Court / Accent / Stance). Locked items are visible but
/// dimmed and show their unlock requirement on tap.
struct AvatarLockerRoomView: View {
    @EnvironmentObject private var avatarManager: AvatarManager
    @EnvironmentObject private var lang: LanguageManager
    @Environment(\.dismiss) private var dismiss

    @State private var category: AvatarCategory = .outfit
    @State private var lockedItemAlert: AvatarUnlock?

    var body: some View {
        VStack(spacing: 0) {
            preview
            categoryPicker
            itemGrid
        }
        .background(AppPalette.cream)
        .navigationTitle(lang.t("avatar.locker_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(lang.t("common.done")) { dismiss() }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppPalette.clay)
            }
        }
        .alert(
            lockedItemAlert?.unlockHint(language: lang.language) ?? "",
            isPresented: Binding(
                get: { lockedItemAlert != nil },
                set: { if !$0 { lockedItemAlert = nil } }
            )
        ) {
            Button(lang.t("common.ok"), role: .cancel) {}
        }
    }

    // MARK: - Preview

    private var preview: some View {
        ZStack {
            TennisAvatarView(config: avatarManager.config, size: 240)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(AppPalette.parchment)
    }

    // MARK: - Category picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                categoryPill(.outfit, icon: "tshirt.fill")
                categoryPill(.racket, icon: "figure.tennis")
                categoryPill(.court,  icon: "square.grid.2x2.fill")
                categoryPill(.accent, icon: "sparkles")
                categoryPill(.stance, icon: "figure.stand")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }

    private func categoryPill(_ cat: AvatarCategory, icon: String) -> some View {
        let isActive = category == cat
        return Button {
            Haptics.tap()
            category = cat
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(categoryLabel(cat))
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(isActive ? .white : AppPalette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isActive ? AppPalette.clay : AppPalette.parchment)
            )
            .overlay(
                Capsule().stroke(AppPalette.sand, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func categoryLabel(_ cat: AvatarCategory) -> String {
        switch cat {
        case .outfit: return lang.t("avatar.cat_outfit")
        case .racket: return lang.t("avatar.cat_racket")
        case .court:  return lang.t("avatar.cat_court")
        case .accent: return lang.t("avatar.cat_accent")
        case .stance: return lang.t("avatar.cat_stance")
        }
    }

    // MARK: - Item grid

    @ViewBuilder
    private var itemGrid: some View {
        let cols = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
        ]
        ScrollView {
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(itemsForCurrentCategory(), id: \.0) { item in
                    itemCell(itemID: item.0, displayName: item.1)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .padding(.bottom, 100)
        }
    }

    private func itemsForCurrentCategory() -> [(String, String)] {
        switch category {
        case .outfit: return AvatarOutfit.allCases.map { ($0.rawValue, $0.displayName) }
        case .racket: return AvatarRacket.allCases.map { ($0.rawValue, $0.displayName) }
        case .court:  return AvatarCourtBg.allCases.map { ($0.rawValue, $0.displayName) }
        case .accent: return AvatarAccent.allCases.map { ($0.rawValue, $0.displayName) }
        case .stance: return AvatarStance.allCases.map { ($0.rawValue, $0.displayName) }
        }
    }

    private func itemCell(itemID: String, displayName: String) -> some View {
        let unlocked = avatarManager.isUnlocked(itemID)
        let selected = isSelected(itemID: itemID)

        return Button {
            handleTap(itemID: itemID)
        } label: {
            VStack(spacing: 6) {
                // Mini preview swatch — flat color tile sufficient
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(swatchColor(for: itemID))
                        .frame(height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(
                                    selected ? AppPalette.clay : Color.clear,
                                    lineWidth: 2.5
                                )
                        )
                        .opacity(unlocked ? 1 : 0.45)

                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    if selected && unlocked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.trailing, 6)
                            .padding(.bottom, 6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: .bottomTrailing)
                    }
                }

                Text(displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(unlocked ? AppPalette.ink : AppPalette.inkSoft)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func isSelected(itemID: String) -> Bool {
        switch category {
        case .outfit: return avatarManager.config.outfitID == itemID
        case .racket: return avatarManager.config.racketID == itemID
        case .court:  return avatarManager.config.courtSurfaceID == itemID
        case .accent: return avatarManager.config.accentID == itemID
        case .stance: return avatarManager.config.stanceID == itemID
        }
    }

    /// Color swatch for the item tile preview. Chosen to communicate the
    /// item's vibe without rendering the full avatar 30 times.
    private func swatchColor(for itemID: String) -> Color {
        if let outfit = AvatarOutfit(rawValue: itemID)  { return outfit.jerseyColor }
        if let racket = AvatarRacket(rawValue: itemID)  { return racket.headColor }
        if let court = AvatarCourtBg(rawValue: itemID)  { return court.surface.base }
        // Accent / stance — show neutral chip
        return AppPalette.parchment
    }

    private func handleTap(itemID: String) {
        let unlocked = avatarManager.isUnlocked(itemID)
        guard unlocked else {
            if let rule = AvatarManager.unlockRules.first(where: { $0.itemID == itemID }) {
                lockedItemAlert = rule
            }
            Haptics.warning()
            return
        }
        Haptics.tap()
        var updated = avatarManager.config
        switch category {
        case .outfit: updated.outfitID = itemID
        case .racket: updated.racketID = itemID
        case .court:  updated.courtSurfaceID = itemID
        case .accent: updated.accentID = itemID
        case .stance: updated.stanceID = itemID
        }
        avatarManager.apply(updated)
    }
}
