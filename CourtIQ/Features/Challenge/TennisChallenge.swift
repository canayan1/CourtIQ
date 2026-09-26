import Foundation

/// A head-to-head challenge: the same five scenarios, played by two people,
/// carried entirely inside a link.
///
/// **There is no server.** The link *is* the challenge — it names the five
/// questions and the challenger's score, and nothing else exists. That was a
/// deliberate choice: a backend would mean accounts, rows, moderation and a
/// bill, for a feature whose whole job is to travel. It also means a challenge
/// keeps working offline, forever, with no row to expire.
///
/// The cost is that the challenger is not told the reply automatically — the
/// reply comes back as another link. That link has to say it is a reply, which
/// is what `replierScore` is for. Version 1 could not: a reply was byte-for-byte
/// an opening challenge, so the app greeted the original challenger with "can
/// you beat it?" and asked them to replay five scenarios they had just answered
/// and knew the answers to. They scored five out of five and "won". The loop
/// the comment above claims did not close; it doubled back.
struct TennisChallenge: Equatable {
    /// Payload format version. Bumped only if the byte layout changes — the
    /// question set is addressed by content hash, so adding, removing or
    /// reordering scenarios does not need a new version.
    ///
    /// v1 = `[1][5 × 3-byte hash][score]`, opening challenges only.
    /// v2 = `[2][5 × 3-byte hash][kind][scoreA][scoreB]`, which can also say
    /// "this is the answer to the one you sent".
    static let version: UInt8 = 2

    /// How many scenarios one challenge carries.
    static let length = 5

    let questionIDs: [String]
    /// Whoever sent the ORIGINAL challenge — not whoever sent this link.
    let challengerScore: Int
    /// Set only on a reply: what the person who was challenged scored. Its
    /// presence is what makes this a result rather than an invitation.
    let replierScore: Int?

    /// A reply is a finished head-to-head. Both numbers are already known, so
    /// there is nothing left to play.
    var isReply: Bool { replierScore != nil }

    init?(questionIDs: [String], challengerScore: Int, replierScore: Int? = nil) {
        guard questionIDs.count == Self.length,
              (0...questionIDs.count).contains(challengerScore),
              replierScore.map({ (0...questionIDs.count).contains($0) }) ?? true
        else { return nil }
        self.questionIDs = questionIDs
        self.challengerScore = challengerScore
        self.replierScore = replierScore
    }

    /// The link sent back after playing someone's challenge. It carries BOTH
    /// numbers, so the original challenger opens a result and never re-answers
    /// questions they have already seen.
    func reply(withMyScore mine: Int) -> TennisChallenge? {
        TennisChallenge(questionIDs: questionIDs,
                        challengerScore: challengerScore,
                        replierScore: mine)
    }
}

// MARK: - Addressing questions by content, not by position

/// A question is named in a link by a 24-bit hash of its id, never by its index
/// in the bank. An index would break the moment a scenario was inserted,
/// removed or re-sorted — and a link that silently plays the *wrong* five
/// questions is worse than one that fails.
///
/// FNV-1a, because it has to be identical on every device and every build:
/// Swift's own `hashValue` is seeded per process and would give two phones two
/// different answers for the same string.
enum ChallengeHash {
    static func fnv1a24(_ s: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in Array(s.utf8) {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return hash & 0x00FF_FFFF
    }
}

// MARK: - Codec

enum ChallengeCodec {
    /// `[2][h0…h4 · 3 bytes each][kind][scoreA][scoreB]` → 19 bytes → 26
    /// base64url characters, which keeps the shared URL short enough to read
    /// aloud. `kind` is 0 for an invitation and 1 for a result being sent back.
    private static let kindOpening: UInt8 = 0
    private static let kindReply: UInt8   = 1

    /// v1's byte count, still accepted when decoding so links already sent keep
    /// working. Nothing writes it any more.
    private static let v1ByteCount = 2 + TennisChallenge.length * 3
    private static let v2ByteCount = 4 + TennisChallenge.length * 3

    static func encode(_ challenge: TennisChallenge) -> String {
        var bytes: [UInt8] = [TennisChallenge.version]
        for id in challenge.questionIDs {
            let h = ChallengeHash.fnv1a24(id)
            bytes.append(UInt8((h >> 16) & 0xFF))
            bytes.append(UInt8((h >> 8) & 0xFF))
            bytes.append(UInt8(h & 0xFF))
        }
        bytes.append(challenge.isReply ? kindReply : kindOpening)
        bytes.append(UInt8(challenge.challengerScore))
        bytes.append(UInt8(challenge.replierScore ?? 0))
        return base64URL(Data(bytes))
    }

    enum DecodeError: Error {
        /// The payload is not a challenge at all — wrong length, bad characters.
        case malformed
        /// A newer app made this link. Ask the player to update rather than
        /// guessing at a layout we do not know.
        case unsupportedVersion
        /// Every scenario is addressed by content hash, so this means the bank
        /// no longer contains one of them.
        case questionMissing
    }

    /// Resolves the payload against a live question bank. Accepts v1 as well as
    /// v2 — a v1 link is an opening challenge, which is all v1 could express.
    static func decode(_ payload: String, bank: [QuizQuestion]) throws -> TennisChallenge {
        guard let data = dataFromBase64URL(payload) else { throw DecodeError.malformed }
        let bytes = [UInt8](data)
        guard let version = bytes.first else { throw DecodeError.malformed }

        switch (version, bytes.count) {
        case (1, v1ByteCount), (2, v2ByteCount): break
        // A version we know with the wrong length is a corrupted link, not a
        // future one; saying "update the app" there would be a lie.
        case (1, _), (2, _):                     throw DecodeError.malformed
        default:                                 throw DecodeError.unsupportedVersion
        }

        var byHash: [UInt32: String] = [:]
        for q in bank { byHash[ChallengeHash.fnv1a24(q.id)] = q.id }

        var ids: [String] = []
        for i in 0..<TennisChallenge.length {
            let o = 1 + i * 3
            let h = (UInt32(bytes[o]) << 16) | (UInt32(bytes[o + 1]) << 8) | UInt32(bytes[o + 2])
            guard let id = byHash[h] else { throw DecodeError.questionMissing }
            ids.append(id)
        }

        let challenge: TennisChallenge?
        if version == 1 {
            challenge = TennisChallenge(questionIDs: ids, challengerScore: Int(bytes[bytes.count - 1]))
        } else {
            let tail = 1 + TennisChallenge.length * 3
            let isReply = bytes[tail] == kindReply
            challenge = TennisChallenge(questionIDs: ids,
                                        challengerScore: Int(bytes[tail + 1]),
                                        replierScore: isReply ? Int(bytes[tail + 2]) : nil)
        }
        guard let challenge else { throw DecodeError.malformed }
        return challenge
    }

    // MARK: base64url

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func dataFromBase64URL(_ s: String) -> Data? {
        var t = s.replacingOccurrences(of: "-", with: "+")
                 .replacingOccurrences(of: "_", with: "/")
        while t.count % 4 != 0 { t.append("=") }
        return Data(base64Encoded: t)
    }
}

// MARK: - The link

extension TennisChallenge {
    /// `https://samosfi.com/c/<payload>` — our domain, registered for universal
    /// links, and a page that offers the App Store when the app is not
    /// installed. Never a third party's domain.
    var url: URL {
        URL(string: "https://samosfi.com/c/\(ChallengeCodec.encode(self))")
            ?? URL(string: "https://samosfi.com")!
    }

    /// Builds a challenge from the questions a player just answered.
    static func from(questions: [QuizQuestion], score: Int) -> TennisChallenge? {
        TennisChallenge(questionIDs: Array(questions.prefix(length)).map(\.id),
                        challengerScore: min(score, length))
    }
}
