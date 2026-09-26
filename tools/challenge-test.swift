// Checks what a head-to-head link promises.
//
//   cp tools/challenge-test.swift /tmp/main.swift
//   swiftc -O /tmp/main.swift \
//          CourtIQ/Features/Challenge/TennisChallenge.swift \
//          tools/ChallengeTestStubs.swift -o /tmp/ch && /tmp/ch
//
// None of this is visible on a screen. A challenge is nineteen bytes travelling
// through a messaging app, and every claim it makes is a claim about those
// bytes:
//
//   1. A reply is distinguishable from an invitation. v1 could not do this, so
//      the original challenger was asked to replay five scenarios they had just
//      answered — and, knowing every answer, "won".
//   2. A reply carries BOTH scores. The old reply builder wrote the replier's
//      score into the challenger's field, so the first number was simply lost.
//   3. v1 links still open. They were only ever invitations, so that is what
//      they decode to.
//   4. A question is addressed by content, never by position in the bank.

import Foundation

var failures = 0
func expect(_ ok: Bool, _ what: String) {
    print((ok ? "  ok   " : "  FAIL ") + what)
    if !ok { failures += 1 }
}

let bank = (0..<40).map { QuizQuestion(id: "q_\($0)") }
let five = Array(bank.prefix(5)).map(\.id)

print("an invitation:")
let invite = TennisChallenge(questionIDs: five, challengerScore: 3)!
expect(!invite.isReply, "is not a reply")
let inviteRound = try! ChallengeCodec.decode(ChallengeCodec.encode(invite), bank: bank)
expect(inviteRound == invite, "survives a round trip")
expect(!inviteRound.isReply, "…still not a reply on the other side")

print("\na reply:")
let reply = invite.reply(withMyScore: 4)!
expect(reply.isReply, "is a reply")
expect(reply.challengerScore == 3, "keeps the challenger's 3")
expect(reply.replierScore == 4, "carries the replier's 4")
let replyRound = try! ChallengeCodec.decode(ChallengeCodec.encode(reply), bank: bank)
expect(replyRound == reply, "survives a round trip")
expect(replyRound.isReply, "…and is still recognisable as a reply")
expect(replyRound.challengerScore == 3 && replyRound.replierScore == 4,
       "…with both numbers intact, got \(replyRound.challengerScore)/\(replyRound.replierScore ?? -1)")

print("\nthe bug this replaced:")
// The old reply builder was `TennisChallenge.from(questions:score:)`, which put
// the replier's score in the challenger's slot. Reconstructed here to show what
// it cost: the challenger's number vanished and the link became an invitation.
let oldStyleReply = TennisChallenge(questionIDs: five, challengerScore: 4)!
expect(!oldStyleReply.isReply,
       "the old reply was indistinguishable from an invitation")
expect(oldStyleReply.challengerScore != invite.challengerScore,
       "…and had overwritten the challenger's score with the replier's")

print("\na reply cannot be replied to:")
// Nothing in the model forbids it, so the view is what must refuse — but the
// data should at least make the state legible.
expect(replyRound.isReply, "a reply says so, which is what the view keys off")

print("\nv1 links still open:")
// Hand-built v1 payload: [1][5 x 3-byte hash][score]
var v1: [UInt8] = [1]
for id in five {
    let h = ChallengeHash.fnv1a24(id)
    v1 += [UInt8((h >> 16) & 0xFF), UInt8((h >> 8) & 0xFF), UInt8(h & 0xFF)]
}
v1.append(2)
let v1Payload = ChallengeCodec.base64URL(Data(v1))
if let decoded = try? ChallengeCodec.decode(v1Payload, bank: bank) {
    expect(decoded.questionIDs == five, "a v1 link resolves the same five")
    expect(decoded.challengerScore == 2, "…and its score")
    expect(!decoded.isReply, "…and is read as an invitation, which is all it could be")
} else {
    expect(false, "a v1 link still decodes")
}

print("\nbad links fail as the right kind of bad:")
func failure(_ payload: String) -> ChallengeCodec.DecodeError? {
    do { _ = try ChallengeCodec.decode(payload, bank: bank); return nil }
    catch let e as ChallengeCodec.DecodeError { return e }
    catch { return nil }
}
expect(failure("not-base64!!") == .malformed, "junk is malformed")
expect(failure("") == .malformed, "empty is malformed")
var truncated = [UInt8](ChallengeCodec.dataFromBase64URL(ChallengeCodec.encode(invite))!)
truncated.removeLast(3)
expect(failure(ChallengeCodec.base64URL(Data(truncated))) == .malformed,
       "a known version at the wrong length is malformed, not 'update the app'")
var future = [UInt8](ChallengeCodec.dataFromBase64URL(ChallengeCodec.encode(invite))!)
future[0] = 9
expect(failure(ChallengeCodec.base64URL(Data(future))) == .unsupportedVersion,
       "an unknown version asks for an update")
var unknownQuestion = [UInt8](ChallengeCodec.dataFromBase64URL(ChallengeCodec.encode(invite))!)
unknownQuestion[1] ^= 0xFF
expect(failure(ChallengeCodec.base64URL(Data(unknownQuestion))) == .questionMissing,
       "a hash the bank does not hold is a missing question")

print("\nquestions are addressed by content, not position:")
let shuffled = bank.shuffled()
let viaShuffled = try! ChallengeCodec.decode(ChallengeCodec.encode(invite), bank: shuffled)
expect(viaShuffled.questionIDs == five,
       "reordering the bank does not change which five a link names")
let grown = bank + (100..<140).map { QuizQuestion(id: "new_\($0)") }
let viaGrown = try! ChallengeCodec.decode(ChallengeCodec.encode(invite), bank: grown)
expect(viaGrown.questionIDs == five, "adding scenarios does not either")

print("\nscores outside the range are refused:")
expect(TennisChallenge(questionIDs: five, challengerScore: 6) == nil, "6 out of 5 is not a score")
expect(TennisChallenge(questionIDs: five, challengerScore: -1) == nil, "neither is -1")
expect(TennisChallenge(questionIDs: five, challengerScore: 3, replierScore: 9) == nil,
       "…and the same applies to the replier's")
expect(TennisChallenge(questionIDs: Array(five.prefix(4)), challengerScore: 2) == nil,
       "four questions is not a challenge")

print("\nthe link is ours:")
expect(invite.url.host == "samosfi.com", "the share URL points at samosfi.com")
expect(invite.url.path.hasPrefix("/c/"), "…on the /c/ path the AASA covers")

print(failures == 0 ? "\nall good" : "\n\(failures) failed")
exit(failures == 0 ? 0 : 1)
