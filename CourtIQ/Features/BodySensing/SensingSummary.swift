import Foundation

/// What the AI Coach is handed when a match with a recorded session is logged.
///
/// During the match the player gets raw data on the bench. Afterwards, when
/// they log it in the Journal, the whole session goes to the coach — but as
/// measurements with their limits attached, never as conclusions. The block
/// opens with the rules because the model has no other way of knowing them:
/// these are observations from a wrist or a belt; they cannot see a cause;
/// nothing on nutrition, hydration or fatigue may be inferred from them. The
/// app's own rule that nutrition content carries no unsourced dietary advice
/// applies to the coach's output exactly as it applies to a screen.
enum SensingSummary {

    static func coachBlock(for entry: MatchEntry) -> String? {
        let store = SensingSessionStore.shared
        let session: SensingSession?
        if let id = entry.sensingSessionID {
            session = store.load(id)
        } else if let near = store.nearest(to: entry.date),
                  // The fallback attaches a session to a MATCH. A wall drill
                  // or a serving session on the same day is not that match,
                  // and judging a match on wall rules would hand the coach the
                  // wrong session with a straight face — so only sessions
                  // that were a match or free play, and only within three
                  // hours of the match's own time, are ever attached this way.
                  [DrillContext.Kind.match.rawValue, DrillContext.Kind.freePlay.rawValue].contains(near.drill),
                  abs(near.startedAt.timeIntervalSince(entry.date)) < 3 * 3600 {
            session = near
        } else {
            session = nil
        }
        guard let session else { return nil }
        let events = session.decodedEvents
        guard events.count > 20 else { return nil }

        var lines: [String] = []
        lines.append("Measured session (device sensors — \(session.highRateMotion ? "watch, 800 Hz" : "100 Hz")).")
        lines.append("RULES FOR THESE NUMBERS: they are observations of movement and contact, "
                     + "not diagnoses. Do not infer or suggest causes such as fatigue, fitness, "
                     + "nutrition, carbohydrate, hydration or sleep — none of those can be read "
                     + "from this data. Give no dietary advice. Report what changed and where to "
                     + "look; the player draws the line.")

        let own = events.filter { if case .contact(_, _, .player) = $0 { return true }; return false }.count
        let opp = events.filter { if case .contact(_, _, .opponent) = $0 { return true }; return false }.count
        lines.append("Contacts: player \(own), opponent \(opp).")

        let stints = session.stints
        if !stints.isEmpty {
            lines.append("Stints (between changeovers):")
            for s in stints {
                var part = String(format: "  #%d %.0f min — moves/min %.0f, push peak %.2f g, moving %.0f%%",
                                  s.index + 1, s.duration / 60, s.effortsPerMinute,
                                  s.medianPeakPush, s.movingShare * 100)
                if let r = s.readiness { part += String(format: ", split-stepped on %.0f%%", r * 100) }
                if let hr = s.meanHeartRate { part += String(format: ", HR %.0f", hr) }
                lines.append(part)
            }
            for n in session.benchNotes { lines.append("  Last stint vs previous: " + n.sentence) }
        }

        // The omission detector, on the event stream. With no raw motion in
        // the stream the rules that need it report themselves unchecked, and
        // that list goes to the coach too — silence must not read as praise
        // there either.
        let ownTimes = events.compactMap { e -> Double? in
            if case .contact(let t, _, .player) = e { return t }; return nil }
        let oppTimes = events.compactMap { e -> Double? in
            if case .contact(let t, _, .opponent) = e { return t }; return nil }
        let hops = events.compactMap { e -> SplitStep? in
            if case .splitStep(let t, let g) = e { return SplitStep(landing: t, unload: 0, landingG: g) }
            return nil }
        let efforts = events.compactMap { e -> (t: Double, peak: Double)? in
            if case .effort(let t, let p) = e { return (t, p) }; return nil }
        // The drill decides which rules are fair, and rhythm is read from
        // the player's own contacts so the one-repeated-action drills can be
        // judged on whether their tempo held.
        let kind = DrillContext.Kind(rawValue: session.drill) ?? .freePlay
        let findings = SessionAnalyst.analyse(ownContacts: ownTimes, opponentContacts: oppTimes,
                                              splitSteps: hops, motion: [],
                                              rhythm: RallyRhythmReader.read(strokes: ownTimes),
                                              drill: kind, efforts: efforts)
        if !findings.findings.isEmpty {
            lines.append("Flagged:")
            for f in findings.findings { lines.append("  " + f.sentence) }
        }
        if !findings.notChecked.isEmpty {
            lines.append("Not checked (say so if relevant, do not guess):")
            for r in findings.notChecked { lines.append("  " + r) }
        }

        // Against the player's own history, same kind of session. This is
        // the analytics: not how this session compares with anyone else, but
        // with the last several of theirs.
        let history = store.all().filter { $0.id != session.id && $0.drill == session.drill }
        let trend = SessionTrends.compare(current: session, history: history)
        if !trend.notes.isEmpty {
            lines.append("Against this player's previous \(trend.baselineCount) \(session.drill) sessions:")
            for n in trend.notes { lines.append("  " + n.sentence) }
        } else if let why = trend.notCompared {
            lines.append("Trend: " + why)
        }
        return lines.joined(separator: "\n")
    }
}
