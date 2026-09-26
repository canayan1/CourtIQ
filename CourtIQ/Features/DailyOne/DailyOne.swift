import Foundation

/// The one question everybody gets today.
///
/// The Daily IQ session next door is adaptive — it picks your weakest
/// category, your oldest miss, the ones you haven't seen. That is the right
/// way to teach one player and the wrong way to start a conversation: two
/// people never hold the same question, so there is nothing to argue about.
///
/// This is the other thing. One scenario, the same one in Dublin and in
/// Istanbul, chosen by the date and nothing else. It teaches less and it
/// travels further.
///
/// Three properties the rest of the feature leans on:
///
/// * **Same question.** The pick is a pure function of the day. No state, no
///   account, no network — a phone in flight mode shows what everyone else
///   is seeing.
/// * **Same order.** The bundled bank shuffles each question's options at
///   load (the bank is authored correct-answer-first, so shipping it
///   verbatim would make every answer "A"). That shuffle is random per
///   launch, which would make "61% said B" a sentence about nothing. The
///   daily question is taken *unshuffled* and permuted by the date instead,
///   so every device lays out the same A, B, C.
/// * **Stable identity.** A vote travels as the option's index in the JSON,
///   never as the position it happened to be drawn in. Redesign the
///   presentation tomorrow and yesterday's counts still mean what they said.
enum DailyOne {

    /// One day's question, already ordered for display.
    struct Pick: Equatable {
        let dayKey: String
        let question: QuizQuestion       // options in the day's order
        /// Displayed position -> index of that option in the bundled JSON.
        let originalIndices: [Int]

        var correctDisplayedIndex: Int { question.correctAnswerIndex }

        /// What a vote for displayed position `i` is called on the wire.
        func originalIndex(ofDisplayed i: Int) -> Int? {
            originalIndices.indices.contains(i) ? originalIndices[i] : nil
        }
    }

    // MARK: The day

    /// UTC, because the question is shared and a shared thing cannot start at
    /// a different moment for each person who holds it. Everyone rolls over
    /// together at midnight GMT — for Ireland that is midnight most of the
    /// year and 1am in summer, which is close enough to "a new day" and far
    /// better than Dublin and Istanbul arguing about different questions for
    /// two hours every evening.
    static func dayKey(for date: Date = Date()) -> String {
        dayFormatter.string(from: date)
    }

    static func dayIndex(for date: Date = Date()) -> Int {
        Int(floor(date.timeIntervalSince1970 / 86_400))
    }

    static func date(fromDayKey key: String) -> Date? {
        dayFormatter.date(from: key)
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    // MARK: The pick

    /// The rota: the whole bank in one fixed pseudo-random order. Walking it
    /// by day index means no repeat until every question has had its turn,
    /// and the order is not the file's order — otherwise the first fortnight
    /// would be fourteen serve questions.
    private static let rota: [QuizQuestion] = {
        var rng = SplitMix64(seed: 0x44_52_4F_50_56_4F_4C)   // "DROPVOL"
        return Quiz.unshuffledBank
            .sorted { $0.id < $1.id }                        // stable input
            .shuffled(using: &rng)
    }()

    static func pick(for date: Date = Date()) -> Pick? {
        guard !rota.isEmpty else { return nil }
        let index = dayIndex(for: date)
        // Negative indices (a device with its clock before 1970) would trap
        // on %, and there is no useful question to show such a device anyway.
        guard index >= 0 else { return nil }
        let question = rota[index % rota.count]
        return ordered(question, dayIndex: index, dayKey: dayKey(for: date))
    }

    /// Permutes one question's options deterministically from the day.
    static func ordered(_ question: QuizQuestion, dayIndex: Int, dayKey: String) -> Pick {
        let count = question.options.count
        guard count > 1 else {
            return Pick(dayKey: dayKey, question: question,
                        originalIndices: Array(0..<count))
        }
        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(dayIndex)) &* 0x9E37_79B9_7F4A_7C15 &+ 1)
        let order = Array(0..<count).shuffled(using: &rng)

        var copy = question
        copy.options = order.map { question.options[$0] }
        if let tr = question.optionsTr, tr.count == count {
            copy.optionsTr = order.map { tr[$0] }
        }
        if let fr = question.optionsFr, fr.count == count {
            copy.optionsFr = order.map { fr[$0] }
        }
        copy.correctAnswerIndex = order.firstIndex(of: question.correctAnswerIndex) ?? 0
        return Pick(dayKey: dayKey, question: copy, originalIndices: order)
    }
}

/// Seeded, portable, and identical on every device and OS version.
///
/// `SystemRandomNumberGenerator` is none of those things, and
/// `Array.shuffled()` uses it. A daily question that differs between two
/// phones is not a daily question.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
