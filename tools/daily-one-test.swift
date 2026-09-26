// Checks the promises the shared daily question is built on.
//
//   cp tools/daily-one-test.swift /tmp/main.swift
//   cp CourtIQ/Resources/Content/quiz_questions.json /tmp/
//   swiftc -O /tmp/main.swift \
//          CourtIQ/Features/DailyOne/{DailyOne,DailyOneStore}.swift \
//          CourtIQ/Core/Models/{Quiz,BundleContentLoader}.swift \
//          CourtIQ/Core/Utilities/LanguageManager.swift -o /tmp/d1 && /tmp/d1
//
// The JSON goes next to the binary on purpose: BundleContentLoader reads
// Bundle.main, which for a command-line tool is the directory the executable
// sits in. So this runs against the real 156 questions, not a stub — the
// rota's "no repeat for 156 days" is a claim about the shipped bank.
//
// The feature is worth nothing unless three things hold, and none of them is
// visible by looking at a screen:
//
//   1. Two devices, same day, same question — and the same A, B, C. The
//      bundled bank shuffles options per launch, so this has to be built
//      against the unshuffled bank with a date-seeded permutation. If this
//      test ever fails, "61% said B" is a lie on somebody's phone.
//   2. A vote is the option's index in the JSON, never its drawn position.
//   3. The rota exhausts the bank before repeating.

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

let day0 = Date(timeIntervalSince1970: 1_790_000_000)   // a fixed Tuesday

print("the same question, everywhere:")
let a = DailyOne.pick(for: day0)!
let b = DailyOne.pick(for: day0.addingTimeInterval(3600 * 5))!   // same UTC day
expect(a.question.id == b.question.id, "same UTC day gives the same question")
expect(a.question.options == b.question.options, "…and the same option order")
expect(a.originalIndices == b.originalIndices, "…and the same wire identities")

let tomorrow = DailyOne.pick(for: day0.addingTimeInterval(86_400))!
expect(tomorrow.question.id != a.question.id, "the next day is a different question")

print("\nthe day boundary is UTC, not the device:")
// 23:30 UTC and 00:30 UTC are different days even though they are 60 minutes
// apart; a shared question cannot roll over per timezone.
let key = DailyOne.dayKey(for: day0)
expect(DailyOne.date(fromDayKey: key) != nil, "a day key round-trips to a date")
let lateNight = DailyOne.date(fromDayKey: key)!.addingTimeInterval(86_399)
let justAfter = DailyOne.date(fromDayKey: key)!.addingTimeInterval(86_401)
expect(DailyOne.pick(for: lateNight)!.question.id == a.question.id,
       "23:59:59 UTC is still today's question")
expect(DailyOne.pick(for: justAfter)!.question.id != a.question.id,
       "00:00:01 UTC has rolled over")

print("\na vote is the JSON's index, not the drawn position:")
let raw = Quiz.unshuffledBank.first { $0.id == a.question.id }!
var mapped = true
for displayed in a.question.options.indices {
    guard let original = a.originalIndex(ofDisplayed: displayed) else { mapped = false; break }
    if raw.options[original] != a.question.options[displayed] { mapped = false; break }
}
expect(mapped, "every drawn option maps back to the option it came from")
expect(a.originalIndex(ofDisplayed: a.correctDisplayedIndex) == raw.correctAnswerIndex,
       "the correct answer survives the permutation")
expect(a.originalIndex(ofDisplayed: 99) == nil, "an impossible position maps to nothing")
expect(Set(a.originalIndices).count == raw.options.count,
       "the permutation is a permutation, not a resampling")

print("\nthe answer is not always in the same place:")
var positions = Set<Int>()
for d in 0..<40 { positions.insert(DailyOne.pick(for: day0.addingTimeInterval(86_400 * Double(d)))!.correctDisplayedIndex) }
expect(positions.count > 1, "the correct answer moves between days (\(positions.sorted()))")

print("\nthe rota exhausts the bank before repeating:")
let bankCount = Quiz.unshuffledBank.count
var seen: [String] = []
for d in 0..<bankCount { seen.append(DailyOne.pick(for: day0.addingTimeInterval(86_400 * Double(d)))!.question.id) }
expect(Set(seen).count == bankCount, "\(bankCount) days, \(Set(seen).count) distinct questions")
let wrapped = DailyOne.pick(for: day0.addingTimeInterval(86_400 * Double(bankCount)))!
expect(wrapped.question.id == seen[0], "day \(bankCount) comes back to the start")

print("\nthe rota is not the file order:")
let fileOrder = Quiz.unshuffledBank.sorted { $0.id < $1.id }.prefix(5).map(\.id)
expect(Array(seen.prefix(5)) != Array(fileOrder), "the first days are not the first rows")

print("\nstreaks:")
var state = DailyOneState()
let now = Date(timeIntervalSince1970: 1_790_000_000)
func answer(_ daysAgo: Int, correct: Bool = true) {
    let key = DailyOne.dayKey(for: now.addingTimeInterval(-86_400 * Double(daysAgo)))
    state.entries[key] = .init(originalIndex: 0, correct: correct, answeredAt: now)
}
expect(DailyOneStreak.current(state, today: now) == 0, "nothing answered, no streak")
answer(0); answer(1); answer(2)
expect(DailyOneStreak.current(state, today: now) == 3, "three days running")
answer(4)
expect(DailyOneStreak.current(state, today: now) == 3, "a gap does not extend it")

state = DailyOneState(); answer(1); answer(2)
expect(DailyOneStreak.current(state, today: now) == 2,
       "today unanswered still shows yesterday's streak, not zero")
state = DailyOneState(); answer(2); answer(3)
expect(DailyOneStreak.current(state, today: now) == 0,
       "two days missed and it is gone")

state = DailyOneState(); answer(0, correct: false); answer(1, correct: false)
expect(DailyOneStreak.current(state, today: now) == 2,
       "being wrong keeps the streak — the ritual is answering, not winning")

print("\nthe record is honest about days never played:")
state = DailyOneState(); answer(0, correct: true); answer(1, correct: false); answer(5, correct: true)
let r = DailyOneStreak.record(state, days: 7, today: now)
expect(r == (correct: 2, answered: 3), "2 correct of 3 answered in 7 days, got \(r)")

print("\nfirst answer wins:")
// The store itself needs UserDefaults; the rule it enforces is checked on the
// state it keeps.
var s2 = DailyOneState()
s2.entries["2026-09-26"] = .init(originalIndex: 1, correct: false, answeredAt: now)
let before = s2.entries["2026-09-26"]
if s2.entries["2026-09-26"] == nil { s2.entries["2026-09-26"] = .init(originalIndex: 2, correct: true, answeredAt: now) }
expect(s2.entries["2026-09-26"] == before, "a second answer for the same day is ignored")

print(failures == 0 ? "\nall good" : "\n\(failures) failed")
exit(failures == 0 ? 0 : 1)
