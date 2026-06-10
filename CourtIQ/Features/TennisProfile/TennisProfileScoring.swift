import Foundation

/// Pure, deterministic derivation of a Tennis Profile from the answers.
/// Method (evidence-based, see research notes):
/// - LEVEL: the player's background (experience + match play) sets a *floor*;
///   their plain-language self-placement gives a second estimate. We take the
///   HIGHER of the two because recreational players reliably UNDER-rate
///   themselves (USTA self-rating bias). Never let the result read below the
///   background floor.
/// - ARCHETYPE: from the NTRP stroke self-ratings + net comfort + how they
///   play under pressure. Framed positively (no "pusher").
/// - STRENGTHS / GROWTH: the highest- and lowest-rated NTRP dimensions.
/// - GOALS: coaching-standard development priorities for the growth areas +
///   what the player says they want.
enum TennisProfileScoring {

    static func evaluate(_ a: TennisProfileAnswers) -> TennisProfileResult {
        let lvl = level(a)
        let arch = archetype(a, level: lvl)
        let (strengths, growth) = strengthsAndGrowth(a)
        let goals = suggestedGoals(growth: growth, want: a.want, level: lvl)
        return TennisProfileResult(level: lvl, archetype: arch,
                                   strengths: strengths, growthAreas: growth,
                                   suggestedGoals: goals)
    }

    // MARK: Level

    static func level(_ a: TennisProfileAnswers) -> TennisLevel {
        let bg = levelFromBackground(a)
        let sf = levelFromSelf(a.levelSelf)
        // Upward nudge: take the higher of the floor and the self-placement.
        return TennisLevel(rawValue: max(bg.rawValue, sf.rawValue)) ?? sf
    }

    private static func levelFromBackground(_ a: TennisProfileAnswers) -> TennisLevel {
        let exp: Double = {
            switch a.experience {
            case .justStarting: return 0
            case .underOneYear: return 1
            case .oneToThreeYears: return 2
            case .threeToTenYears: return 3
            case .tenPlusYears: return 4
            }
        }()
        let match: Double = {
            switch a.matchExperience {
            case .never: return 0
            case .socialHits: return 1
            case .casualMatches: return 2
            case .leagueMatches: return 3
            case .tournaments: return 4
            }
        }()
        let freq: Double = {
            switch a.frequency {
            case .rarely: return 0
            case .monthly: return 1
            case .weekly: return 2
            case .twiceThrice: return 3
            case .fourPlus: return 4
            }
        }()
        // Match play + experience dominate; frequency is a minor signal.
        let s = exp * 1.0 + match * 1.2 + freq * 0.4   // 0 ... 10.4
        switch s {
        case ..<2.0:  return .new
        case ..<4.0:  return .improver
        case ..<6.5:  return .intermediate
        case ..<8.5:  return .solidClub
        default:      return .advancedClub
        }
    }

    private static func levelFromSelf(_ p: LevelSelfPlacement) -> TennisLevel {
        switch p {
        case .learningBasics:     return .new
        case .keepRallyGoing:     return .improver
        case .consistentMedium:   return .intermediate
        case .dependableDirected: return .solidClub
        case .depthControlSpin:   return .advancedClub
        }
    }

    // MARK: Archetype

    static func archetype(_ a: TennisProfileAnswers, level: TennisLevel) -> TennisArchetype {
        let serve = a.rating(.serve)
        let net = a.rating(.net)
        let ground = Int((Double(a.rating(.forehand) + a.rating(.backhand)) / 2).rounded())
        let move = a.rating(.movement)
        let avg = Double(TennisDimension.allCases.map { a.rating($0) }.reduce(0, +)) / 6.0
        let aggressive = a.pressure == .goForIt || a.pressure == .rushErrors
        let patient = a.pressure == .patientPick || a.pressure == .playSafe

        // Early level + low self-ratings → still building the game.
        if (level == .new || level == .improver) && avg < 2.6 { return .developing }

        // Strong serve + net, net at least as strong as groundstrokes.
        if serve >= 4 && net >= 4 && net >= ground { return .serveVolleyer }
        // Comfortable at the net AND solid from the back → all-court.
        if net >= 4 && ground >= 3 { return .allCourt }
        // Great mover, patient, not a net-rusher → counterpuncher.
        if move >= 4 && patient && net <= 3 { return .counterpuncher }
        // Big groundstrokes, backs themselves → aggressive baseliner.
        if ground >= 4 && aggressive { return .aggressiveBaseliner }

        // Fallbacks by tendency.
        if move >= ground && patient { return .counterpuncher }
        if ground >= net && aggressive { return .aggressiveBaseliner }
        if net >= 4 { return .allCourt }
        return .aggressiveBaseliner
    }

    // MARK: Strengths / growth

    static func strengthsAndGrowth(_ a: TennisProfileAnswers) -> (strengths: [TennisDimension], growth: [TennisDimension]) {
        // Stable order for ties.
        let order = TennisDimension.allCases
        let byHigh = order.sorted { (a.rating($0), -idx($0, order)) > (a.rating($1), -idx($1, order)) }
        let byLow  = order.sorted { (a.rating($0), idx($0, order)) < (a.rating($1), idx($1, order)) }

        var strengths = byHigh.filter { a.rating($0) >= 4 }
        if strengths.isEmpty { strengths = Array(byHigh.prefix(2)) }
        strengths = Array(strengths.prefix(3))

        let strengthSet = Set(strengths.map { $0.rawValue })
        var growth = byLow.filter { a.rating($0) <= 2 && !strengthSet.contains($0.rawValue) }
        if growth.isEmpty { growth = byLow.filter { !strengthSet.contains($0.rawValue) } }
        growth = Array(growth.prefix(3))

        return (strengths, growth)
    }

    private static func idx(_ d: TennisDimension, _ all: [TennisDimension]) -> Int {
        all.firstIndex(of: d) ?? 0
    }

    // MARK: Goals (coaching-standard development priorities)

    static func suggestedGoals(growth: [TennisDimension], want: TennisWant, level: TennisLevel) -> [TennisGoal] {
        var out: [TennisGoal] = []
        for d in growth.prefix(2) { out.append(dimensionGoal(d, level: level)) }
        out.append(wantGoal(want))
        // De-dup by id, keep order, cap at 4 (selected-by-default).
        var seen = Set<String>()
        let deduped = out.filter { seen.insert($0.id).inserted }
        return Array(deduped.prefix(4)).map { var g = $0; g.isSelected = true; return g }
    }

    private static func dimensionGoal(_ d: TennisDimension, level: TennisLevel) -> TennisGoal {
        switch d {
        case .serve:
            return TennisGoal(id: "serve.second_serve", dimension: .serve,
                              titleKey: "goal.serve.title", detailKey: "goal.serve.detail")
        case .ret:
            return TennisGoal(id: "return.deep_in", dimension: .ret,
                              titleKey: "goal.return.title", detailKey: "goal.return.detail")
        case .forehand:
            return TennisGoal(id: "forehand.crosscourt", dimension: .forehand,
                              titleKey: "goal.forehand.title", detailKey: "goal.forehand.detail")
        case .backhand:
            return TennisGoal(id: "backhand.dependable", dimension: .backhand,
                              titleKey: "goal.backhand.title", detailKey: "goal.backhand.detail")
        case .net:
            return TennisGoal(id: "net.close", dimension: .net,
                              titleKey: "goal.net.title", detailKey: "goal.net.detail")
        case .movement:
            return TennisGoal(id: "movement.splitstep", dimension: .movement,
                              titleKey: "goal.movement.title", detailKey: "goal.movement.detail")
        }
    }

    private static func wantGoal(_ want: TennisWant) -> TennisGoal {
        switch want {
        case .compete:
            return TennisGoal(id: "want.compete", dimension: nil,
                              titleKey: "goal.compete.title", detailKey: "goal.compete.detail")
        case .technique:
            return TennisGoal(id: "want.technique", dimension: nil,
                              titleKey: "goal.technique.title", detailKey: "goal.technique.detail")
        case .fitness:
            return TennisGoal(id: "want.fitness", dimension: nil,
                              titleKey: "goal.fitness.title", detailKey: "goal.fitness.detail")
        case .consistency:
            return TennisGoal(id: "want.consistency", dimension: nil,
                              titleKey: "goal.consistency.title", detailKey: "goal.consistency.detail")
        case .fun:
            return TennisGoal(id: "want.fun", dimension: nil,
                              titleKey: "goal.fun.title", detailKey: "goal.fun.detail")
        }
    }
}
