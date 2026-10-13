import Foundation
import AVFoundation
import UIKit

/// The signed-in client of `supabase/functions/clips` (docs/CLIPS-SPEC.md).
///
/// Three rules it keeps:
///  * **The phone does the video work.** Trim and compress with
///    `AVAssetExportSession`, make the poster with `AVAssetImageGenerator`;
///    the server only stores bytes. A 10-second 720p clip is ~4 MB.
///  * **Bytes never go through an edge function.** `create` returns a signed
///    upload URL and the client PUTs straight to storage; `finalize` tells the
///    server the bytes landed. (The coach-review path pipes base64 through a
///    function; it is capped at 19 MB and is not reused here.)
///  * **Nothing here decides anything.** Tallies come back as views per kind;
///    the UI shows them side by side and never picks a winner.
enum ClipsService {

    struct Created: Decodable {
        let clipId: String; let code: String; let url: String
        let uploadUrl: String; let posterUploadUrl: String?
    }
    struct Playback: Decodable { let url: String?; let poster: String?; let stroke: String; let durationMs: Int }
    struct VoteResult: Decodable { let ok: Bool; let kind: String; let tally: Tally? }
    struct TallyResponse: Decodable { let tally: Tally? }
    struct MineResponse: Decodable { let clips: [OwnedClip] }
    struct InboxResponse: Decodable { let clips: [InboxClip] }
    struct FriendsResponse: Decodable { let friends: [Friend] }
    struct InviteCode: Decodable { let code: String; let url: String }
    struct Redeemed: Decodable { let ok: Bool; let friend: String; let clipId: String? }

    struct OwnedClip: Decodable, Identifiable, Hashable {
        let id: String; let code: String; let stroke: String; let duration_ms: Int
        let created_at: String; let uploaded_at: String?; let status: String; let url: String; let views: Int
    }
    struct InboxClip: Decodable, Identifiable, Hashable {
        let id: String; let owner: String; let stroke: String; let duration_ms: Int
        let created_at: String; let status: String; let answered: Bool
    }
    struct PinnedSummary: Decodable, Hashable { let id: String; let stroke: String; let poster: String? }
    struct Friend: Decodable, Identifiable, Hashable {
        let friend: String; let since: String; let displayName: String?; let pinned: PinnedSummary?
        var id: String { friend }
    }
    struct Profile: Decodable { let displayName: String?; let pinnedClipId: String? }

    /// One kind's aggregate. `shown == false` means "not enough yet", and the
    /// screen says exactly that rather than showing one person's opinion.
    struct KindTally: Decodable, Hashable {
        let n: Int; let shown: Bool
        let q1: [String: Int]?; let q2: [String: Int]?
        let q3_median_ms: Double?; let q4_mean: Double?; let q4_n: Int?
        let score_mean: Double?; let score_n: Int?
    }
    struct Declared: Decodable, Hashable { let system: String?; let value: Double?; let band: String? }
    struct Tally: Decodable, Hashable {
        let coach: KindTally?; let player: KindTally?; let web: KindTally?; let ai: KindTally?
        let declared: Declared?
        func kind(_ k: String) -> KindTally? { switch k { case "coach": coach; case "player": player; case "web": web; case "ai": ai; default: nil } }
    }

    enum Failure: Error, LocalizedError {
        case notConfigured, server(String), export, upload(Int), dailyCap(Int)
        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Clips are not configured."
            case .server(let s): return s
            case .export: return "Could not prepare the video."
            case .upload(let c): return "Upload failed (\(c))."
            case .dailyCap(let n): return "You've shared \(n) clips today — that's the daily limit."
            }
        }
    }

    // MARK: - Calls

    static func create(stroke: String, durationMs: Int, rating: (system: String, value: Double?, band: String?)?, session: SupabaseSession) async throws -> Created {
        var body: [String: Any] = ["action": "create", "stroke": stroke, "durationMs": durationMs]
        if let r = rating {
            var rb: [String: Any] = ["system": r.system]
            if let v = r.value { rb["value"] = v }
            if let b = r.band { rb["band"] = b }
            body["rating"] = rb
        }
        return try await call(body, session: session)
    }

    static func finalize(clipId: String, session: SupabaseSession) async throws {
        struct R: Decodable { let ok: Bool }
        _ = try await call(["action": "finalize", "clipId": clipId], session: session) as R
    }

    static func playback(clipId: String, session: SupabaseSession) async throws -> Playback {
        try await call(["action": "playback", "clipId": clipId], session: session)
    }

    static func vote(clipId: String, q1: String, q2: String?, q3Ms: Int?, q4: Double?, score: Int?, session: SupabaseSession) async throws -> VoteResult {
        var body: [String: Any] = ["action": "vote", "clipId": clipId, "q1": q1]
        if let q2 { body["q2"] = q2 }
        if let q3Ms { body["q3Ms"] = q3Ms }
        if let q4 { body["q4"] = q4 }
        if let score { body["score"] = score }
        return try await call(body, session: session)
    }

    static func profile(session: SupabaseSession) async throws -> Profile {
        try await call(["action": "profile_get"], session: session)
    }
    /// `pin == .some(nil)` clears the pin; `nil` leaves it alone.
    static func setProfile(displayName: String?, pin: String??, session: SupabaseSession) async throws {
        struct R: Decodable { let ok: Bool }
        var body: [String: Any] = ["action": "profile_set"]
        if let displayName { body["displayName"] = displayName }
        if let pin { body["pinnedClipId"] = pin ?? NSNull() }
        _ = try await call(body, session: session) as R
    }

    static func tally(clipId: String, session: SupabaseSession) async throws -> Tally? {
        (try await call(["action": "tally", "clipId": clipId], session: session) as TallyResponse).tally
    }

    static func mine(session: SupabaseSession) async throws -> [OwnedClip] {
        (try await call(["action": "mine"], session: session) as MineResponse).clips
    }
    static func inbox(session: SupabaseSession) async throws -> [InboxClip] {
        (try await call(["action": "inbox"], session: session) as InboxResponse).clips
    }
    static func friends(session: SupabaseSession) async throws -> [Friend] {
        (try await call(["action": "friends"], session: session) as FriendsResponse).friends
    }
    static func inviteCode(session: SupabaseSession) async throws -> InviteCode {
        try await call(["action": "invite_code"], session: session)
    }
    static func redeem(code: String, session: SupabaseSession) async throws -> Redeemed {
        try await call(["action": "redeem", "code": code], session: session)
    }
    static func report(clipId: String, reason: String, session: SupabaseSession) async throws {
        struct R: Decodable { let ok: Bool }
        _ = try await call(["action": "report", "clipId": clipId, "reason": reason], session: session) as R
    }
    static func delete(clipId: String, session: SupabaseSession) async throws {
        struct R: Decodable { let ok: Bool }
        _ = try await call(["action": "delete", "clipId": clipId], session: session) as R
    }
    static func applyAsCoach(credentialType: String, credentialRef: String, session: SupabaseSession) async throws {
        struct R: Decodable { let ok: Bool }
        _ = try await call(["action": "coach_apply", "credentialType": credentialType, "credentialRef": credentialRef], session: session) as R
    }

    // MARK: - Upload

    /// PUT the prepared file to the signed upload URL the server minted.
    static func upload(fileURL: URL, to signedURL: String, contentType: String) async throws {
        guard let url = URL(string: signedURL) else { throw Failure.upload(0) }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        req.setValue("true", forHTTPHeaderField: "x-upsert")
        req.timeoutInterval = 120
        let (_, resp) = try await URLSession.shared.upload(for: req, fromFile: fileURL)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw Failure.upload((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    // MARK: - Video preparation (on device)

    struct Prepared { let fileURL: URL; let posterURL: URL?; let durationMs: Int }

    /// Trims to `maxSeconds`, exports 720p H.264 MP4, renders a poster frame.
    /// Done on the phone so the server never transcodes.
    static func prepare(sourceURL: URL, maxSeconds: Double = 12) async throws -> Prepared {
        let asset = AVURLAsset(url: sourceURL)
        let total = try await asset.load(.duration).seconds
        let length = min(total, maxSeconds)
        guard length > 0.5 else { throw Failure.export }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("clips", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let out = dir.appendingPathComponent(UUID().uuidString + ".mp4")
        let poster = dir.appendingPathComponent(UUID().uuidString + ".jpg")

        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else { throw Failure.export }
        export.outputURL = out
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true
        export.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: length, preferredTimescale: 600))
        await export.export()
        guard export.status == .completed else { throw Failure.export }

        var posterURL: URL? = nil
        let gen = AVAssetImageGenerator(asset: AVURLAsset(url: out))
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 720, height: 720)
        if let cg = try? gen.copyCGImage(at: CMTime(seconds: min(0.5, length / 2), preferredTimescale: 600), actualTime: nil),
           let data = UIImage(cgImage: cg).jpegData(compressionQuality: 0.8) {
            try? data.write(to: poster)
            posterURL = poster
        }
        return Prepared(fileURL: out, posterURL: posterURL, durationMs: Int(length * 1000))
    }

    // MARK: - Transport

    private struct ServerError: Decodable { let error: String?; let cap: Int? }

    private static func call<R: Decodable>(_ body: [String: Any], session: SupabaseSession) async throws -> R {
        let config = AppConfiguration.shared
        guard let base = config.supabaseURL, let anon = config.supabaseAnonKey else { throw Failure.notConfigured }
        var req = URLRequest(url: base.appendingPathComponent("functions/v1/clips"))
        req.httpMethod = "POST"
        req.setValue(anon, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 60
        let (data, resp) = try await URLSession.shared.data(for: req)
        let http = resp as? HTTPURLResponse
        if let http, !(200..<300).contains(http.statusCode) {
            let e = try? JSONDecoder().decode(ServerError.self, from: data)
            if e?.error == "daily_cap" { throw Failure.dailyCap(e?.cap ?? 10) }
            throw Failure.server(e?.error ?? "HTTP \(http.statusCode)")
        }
        // Plain decoder on purpose: the function's keys are camelCase/snake as
        // declared above, and the shared app decoder's snake-case strategy
        // would silently break them (see AI-coach decode gotcha in memory).
        return try JSONDecoder().decode(R.self, from: data)
    }
}
