import Foundation

/// What everybody else said — the one part of the daily question that needs a
/// server.
///
/// Three rules it exists to keep:
///
/// * **It never blocks the question.** Every call returns nil rather than
///   throwing: a plane, a dead edge function, a misconfigured build all end
///   the same way, with the player answering and reading the explanation and
///   simply not seeing a percentage. The feature degrades to what it was
///   before the server existed.
/// * **It never invents a crowd.** Below `minimumForPercentages` the split is
///   withheld, because "62% chose B" computed from eight people is noise
///   dressed as evidence, and this app does not ship invented numbers.
/// * **It votes on identity, not position.** What is sent is the option's
///   index in the bundled JSON. Redraw the screen tomorrow, reorder the
///   options, ship a new design — the counts still mean what they meant.
///
/// Nothing identifying is sent: a day, a number between 0 and 3. No account,
/// no device id, no location.
enum DailyOneCrowd {

    /// Below this many answers the percentage is withheld. Fifty is not a
    /// statistical threshold so much as an honesty one — it is the point
    /// where "most players" stops being a sentence about a handful of people.
    static let minimumForPercentages = 50

    struct Split: Equatable {
        /// Option's index in the JSON -> how many chose it.
        let counts: [Int: Int]
        let total: Int

        var isMeaningful: Bool { total >= DailyOneCrowd.minimumForPercentages }

        /// Rounded share for a displayed position, resolved through the day's
        /// permutation so the caller never has to think about wire indices.
        func percentage(forDisplayed i: Int, in pick: DailyOne.Pick) -> Int {
            guard total > 0, let original = pick.originalIndex(ofDisplayed: i),
                  let n = counts[original] else { return 0 }
            return Int((Double(n) / Double(total) * 100).rounded())
        }
    }

    private struct Response: Decodable {
        let total: Int
        let counts: [Int]           // indexed by the option's JSON index
    }

    static func submit(dayKey: String, originalIndex: Int) async -> Split? {
        await call(body: ["day": dayKey, "option": originalIndex])
    }

    static func fetch(dayKey: String) async -> Split? {
        await call(body: ["day": dayKey])
    }

    private static func call(body: [String: Any]) async -> Split? {
        let config = AppConfiguration.shared
        guard let base = config.supabaseURL, let anon = config.supabaseAnonKey,
              let payload = try? JSONSerialization.data(withJSONObject: body)
        else { return nil }

        var request = URLRequest(url: base.appendingPathComponent("functions/v1/daily-one"))
        request.httpMethod = "POST"
        request.setValue(anon, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anon)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload
        // The split is decoration on a screen the player is already reading.
        // It is not worth a spinner and it is certainly not worth a stall.
        request.timeoutInterval = 6

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(Response.self, from: data)
        else { return nil }

        var counts: [Int: Int] = [:]
        for (index, n) in decoded.counts.enumerated() where n > 0 { counts[index] = n }
        return Split(counts: counts, total: decoded.total)
    }
}
