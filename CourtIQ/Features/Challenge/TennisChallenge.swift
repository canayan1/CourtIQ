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
/// reply comes back as another link, or as a message. In practice that is how
/// these spread anyway: the reply is the engagement.
struct TennisChallenge: Equatable {
    /// Payload format version. Bumped only if the byte layout changes — the
    /// question set is addressed by content hash, so adding, removing or
    /// reordering scenarios does not need a new version.
    static let version: UInt8 = 1

    /// How many scenarios one challenge carries.
    static let length = 5

    let questionIDs: [String]
    /// The challenger's score out of `questionIDs.count`.
    let challengerScore: Int

    init?(questionIDs: [String], challengerScore: Int) {
        guard questionIDs.count == Self.length,
              (0...questionIDs.count).contains(challengerScore) else { return nil }
        self.questionIDs = questionIDs
        self.challengerScore = challengerScore
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
    /// `[version][h0…h4 · 3 bytes each][score]` → 17 bytes → 23 base64url
    /// characters, which keeps the shared URL short enough to read aloud.
    static func encode(_ challenge: TennisChallenge) -> String {
        var bytes: [UInt8] = [TennisChallenge.version]
        for id in challenge.questionIDs {
            let h = ChallengeHash.fnv1a24(id)
            bytes.append(UInt8((h >> 16) & 0xFF))
            bytes.append(UInt8((h >> 8) & 0xFF))
            bytes.append(UInt8(h & 0xFF))
        }
        bytes.append(UInt8(challenge.challengerScore))
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

    /// Resolves the payload against a live question bank.
    static func decode(_ payload: String, bank: [QuizQuestion]) throws -> TennisChallenge {
        guard let data = dataFromBase64URL(payload),
              data.count == 2 + TennisChallenge.length * 3 else { throw DecodeError.malformed }
        let bytes = [UInt8](data)
        guard bytes[0] == TennisChallenge.version else { throw DecodeError.unsupportedVersion }

        var byHash: [UInt32: String] = [:]
        for q in bank { byHash[ChallengeHash.fnv1a24(q.id)] = q.id }

        var ids: [String] = []
        for i in 0..<TennisChallenge.length {
            let o = 1 + i * 3
            let h = (UInt32(bytes[o]) << 16) | (UInt32(bytes[o + 1]) << 8) | UInt32(bytes[o + 2])
            guard let id = byHash[h] else { throw DecodeError.questionMissing }
            ids.append(id)
        }
        let score = Int(bytes[bytes.count - 1])
        guard let challenge = TennisChallenge(questionIDs: ids, challengerScore: score) else {
            throw DecodeError.malformed
        }
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
