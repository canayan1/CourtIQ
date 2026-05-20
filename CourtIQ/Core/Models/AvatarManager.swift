import Foundation
import Combine

/// Owns the user's avatar config + the set of unlocked customization
/// items. Items start mostly locked; users earn them by hitting streak,
/// quiz, match, and triple-ring milestones.
@MainActor
final class AvatarManager: ObservableObject {
    static let shared = AvatarManager()

    @Published private(set) var config: AvatarConfig
    @Published private(set) var unlockedIDs: Set<String>

    private let defaults: UserDefaults
    private let configKey = "CourtIQ.avatarConfig.v1"
    private let unlocksKey = "CourtIQ.avatarUnlocks.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.config = Self.loadConfig(from: defaults, key: configKey)
        self.unlockedIDs = Self.loadUnlocks(from: defaults, key: unlocksKey)
        // Always grant the starter set so first-launch users have something.
        self.unlockedIDs.formUnion(Self.starterIDs)
    }

    /// Apply a new configuration. Only persists if every chosen item is
    /// in the unlocked set — defensive against UI bugs that try to set a
    /// locked item.
    func apply(_ newConfig: AvatarConfig) {
        var safe = newConfig
        if !unlockedIDs.contains(safe.outfitID) { safe.outfitID = AvatarConfig.default.outfitID }
        if !unlockedIDs.contains(safe.racketID) { safe.racketID = AvatarConfig.default.racketID }
        if !unlockedIDs.contains(safe.courtSurfaceID) { safe.courtSurfaceID = AvatarConfig.default.courtSurfaceID }
        if !unlockedIDs.contains(safe.accentID) { safe.accentID = AvatarConfig.default.accentID }
        if !unlockedIDs.contains(safe.stanceID) { safe.stanceID = AvatarConfig.default.stanceID }
        config = safe
        persistConfig()
    }

    /// Unlock one item by id. Returns true if this was a new unlock
    /// (allows the caller to surface a celebration).
    @discardableResult
    func unlock(_ id: String) -> Bool {
        let wasNew = !unlockedIDs.contains(id)
        unlockedIDs.insert(id)
        if wasNew { persistUnlocks() }
        return wasNew
    }

    func isUnlocked(_ id: String) -> Bool {
        unlockedIDs.contains(id)
    }

    // MARK: - Milestone check
    //
    // Walks through every unlock rule and grants matching items. Safe to
    // call frequently — only triggers persistence on the first time an
    // unlock fires. Returns the new unlocks for caller celebrations.
    @discardableResult
    func checkMilestones(
        logStreak: Int,
        totalDrillsCompleted: Int,
        totalMatches: Int,
        tripleRingDays: Int
    ) -> [AvatarUnlock] {
        var newlyUnlocked: [AvatarUnlock] = []
        for rule in Self.unlockRules {
            let qualified: Bool
            switch rule.requirement {
            case .logStreak(let n):       qualified = logStreak >= n
            case .drillsCompleted(let n): qualified = totalDrillsCompleted >= n
            case .matchesLogged(let n):   qualified = totalMatches >= n
            case .tripleRingDays(let n):  qualified = tripleRingDays >= n
            case .starter:                qualified = true
            }
            if qualified, unlock(rule.itemID) {
                newlyUnlocked.append(rule)
            }
        }
        return newlyUnlocked
    }

    // MARK: - Persistence

    private func persistConfig() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: configKey)
    }

    private func persistUnlocks() {
        defaults.set(Array(unlockedIDs), forKey: unlocksKey)
    }

    private static func loadConfig(from d: UserDefaults, key: String) -> AvatarConfig {
        guard let data = d.data(forKey: key),
              let decoded = try? JSONDecoder().decode(AvatarConfig.self, from: data)
        else { return .default }
        return decoded
    }

    private static func loadUnlocks(from d: UserDefaults, key: String) -> Set<String> {
        guard let raw = d.array(forKey: key) as? [String] else { return [] }
        return Set(raw)
    }

    // MARK: - Catalog

    /// IDs always unlocked at first launch so the user has a starter set
    /// to mix and match without earning anything.
    static let starterIDs: Set<String> = [
        AvatarOutfit.clayWhite.rawValue,
        AvatarOutfit.classicNavy.rawValue,
        AvatarRacket.classicBlack.rawValue,
        AvatarCourtBg.clayCourt.rawValue,
        AvatarAccent.none.rawValue,
        AvatarStance.ready.rawValue,
    ]

    /// Full unlock ruleset. Hand-tuned to space milestones over weeks/
    /// months so the user always has something next on the horizon.
    static let unlockRules: [AvatarUnlock] = [
        // Starter (always granted, but listed for completeness)
        AvatarUnlock(itemID: AvatarOutfit.clayWhite.rawValue,
                     category: .outfit, requirement: .starter),
        AvatarUnlock(itemID: AvatarOutfit.classicNavy.rawValue,
                     category: .outfit, requirement: .starter),

        // Log-streak unlocks
        AvatarUnlock(itemID: AvatarOutfit.sunsetOrange.rawValue,
                     category: .outfit, requirement: .logStreak(7)),
        AvatarUnlock(itemID: AvatarOutfit.courtRoyal.rawValue,
                     category: .outfit, requirement: .logStreak(14)),
        AvatarUnlock(itemID: AvatarOutfit.midnightTeal.rawValue,
                     category: .outfit, requirement: .logStreak(30)),
        AvatarUnlock(itemID: AvatarOutfit.shadowBlack.rawValue,
                     category: .outfit, requirement: .logStreak(60)),
        AvatarUnlock(itemID: AvatarOutfit.grandSlamCream.rawValue,
                     category: .outfit, requirement: .logStreak(100)),

        // Drill-completion unlocks (rackets)
        AvatarUnlock(itemID: AvatarRacket.clayOrange.rawValue,
                     category: .racket, requirement: .drillsCompleted(10)),
        AvatarUnlock(itemID: AvatarRacket.neonYellow.rawValue,
                     category: .racket, requirement: .drillsCompleted(30)),
        AvatarUnlock(itemID: AvatarRacket.wimbledonGreen.rawValue,
                     category: .racket, requirement: .drillsCompleted(50)),
        AvatarUnlock(itemID: AvatarRacket.carbonGray.rawValue,
                     category: .racket, requirement: .drillsCompleted(100)),
        AvatarUnlock(itemID: AvatarRacket.championGold.rawValue,
                     category: .racket, requirement: .drillsCompleted(200)),

        // Match-logging unlocks (court backgrounds)
        AvatarUnlock(itemID: AvatarCourtBg.grassCourt.rawValue,
                     category: .court, requirement: .matchesLogged(5)),
        AvatarUnlock(itemID: AvatarCourtBg.hardCourt.rawValue,
                     category: .court, requirement: .matchesLogged(15)),
        AvatarUnlock(itemID: AvatarCourtBg.sunsetCourt.rawValue,
                     category: .court, requirement: .matchesLogged(30)),
        AvatarUnlock(itemID: AvatarCourtBg.nightCourt.rawValue,
                     category: .court, requirement: .matchesLogged(50)),

        // Triple-Ring-Day unlocks (accents + stance)
        AvatarUnlock(itemID: AvatarAccent.headband.rawValue,
                     category: .accent, requirement: .tripleRingDays(3)),
        AvatarUnlock(itemID: AvatarAccent.wristbands.rawValue,
                     category: .accent, requirement: .tripleRingDays(7)),
        AvatarUnlock(itemID: AvatarAccent.capForward.rawValue,
                     category: .accent, requirement: .tripleRingDays(20)),
        AvatarUnlock(itemID: AvatarStance.proPose.rawValue,
                     category: .stance, requirement: .tripleRingDays(30)),
    ]
}

/// One unlock rule — pairs an item id with the milestone that grants it.
struct AvatarUnlock: Hashable, Identifiable {
    let itemID: String
    let category: AvatarCategory
    let requirement: UnlockRequirement
    var id: String { itemID }

    /// Short user-facing description like "7-day log streak".
    func unlockHint(language: AppLanguage) -> String {
        requirement.localized(language: language)
    }
}

enum AvatarCategory: Hashable {
    case outfit, racket, court, accent, stance
}

enum UnlockRequirement: Hashable {
    case starter
    case logStreak(Int)
    case drillsCompleted(Int)
    case matchesLogged(Int)
    case tripleRingDays(Int)

    func localized(language: AppLanguage) -> String {
        let tr = language == .turkish
        switch self {
        case .starter:
            return tr ? "Başlangıç" : "Starter"
        case .logStreak(let n):
            return tr ? "\(n) günlük maç logu streak'i" : "\(n)-day log streak"
        case .drillsCompleted(let n):
            return tr ? "\(n) drill tamamla" : "\(n) drills completed"
        case .matchesLogged(let n):
            return tr ? "\(n) maç logla" : "\(n) matches logged"
        case .tripleRingDays(let n):
            return tr ? "\(n) üçlü halka günü" : "\(n) triple-ring days"
        }
    }
}
