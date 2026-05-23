import Foundation
import MultipeerConnectivity
import UIKit

/// Peer-to-peer session for Coach Mode (v1.2).
///
/// CourtIQ Coach Mode pairs two iPhones during a match so each player
/// can log the same set of ratings + a takeaway independently, then
/// reveals the comparison side-by-side. The pairing exists only for
/// the duration of one match — no accounts, no servers, no analytics.
/// Everything goes over MultipeerConnectivity (Bluetooth + local Wi-Fi).
///
/// Why MultipeerConnectivity (MC) and not something newer:
///   • Built into iOS since 7.0, zero third-party deps.
///   • Works fully offline (a tennis court has shaky LTE).
///   • Encrypted by default (`.required` security).
///   • Apple's Network framework is theoretically lower-level but
///     would force us to write our own discovery, handshake, and
///     reconnection. MC ships all three.
///
/// Roles: a session has a HOST (advertises) and a GUEST (browses).
/// The host generates the session ID, which is shared out-of-band via
/// a QR code rendered in `CoachPairView`. Guests scan and immediately
/// browse for an advertiser whose discoveryInfo matches.
///
/// State machine:
///   idle → searching (host advertising | guest browsing)
///        → connecting
///        → connected (both ready to capture ratings)
///        → submittedLocally (waiting for peer)
///        → bothSubmitted (reveal time)
///        → disconnected | failed
@MainActor
final class CoachSession: NSObject, ObservableObject {

    // MARK: - Published state

    enum State: Equatable {
        case idle
        case searching
        case connecting
        case connected
        case submittedLocally
        case bothSubmitted
        case disconnected
        case failed(String)
    }

    enum Role: String { case host, guest }

    @Published private(set) var state: State = .idle
    @Published private(set) var role: Role = .host
    @Published private(set) var peerDisplayName: String?
    /// Ratings + takeaway received from the peer. Becomes non-nil
    /// once the peer has submitted; combined with `localSubmission`
    /// it powers the reveal screen.
    @Published private(set) var peerSubmission: Submission?
    @Published private(set) var localSubmission: Submission?

    /// Stable session ID — used as MC `discoveryInfo` so a guest
    /// browser can pick the right host even if multiple CourtIQ pairs
    /// are happening on the same court.
    let sessionID: String

    // MARK: - Sub-types

    /// Identical shape on both sides. Encoded as JSON for the wire
    /// format; keeping it standalone (not coupled to MatchEntry) means
    /// future tweaks to MatchEntry don't break peer compatibility.
    struct Submission: Codable, Equatable {
        var serveRating: Int
        var returnRating: Int
        var movementRating: Int
        var mentalRating: Int
        var takeaway: String

        var asAverages: [Int] {
            [serveRating, returnRating, movementRating, mentalRating]
        }
    }

    // MARK: - MultipeerConnectivity wiring

    private let serviceType = "courtiq-coach"     // 1-15 chars, lowercase, hyphens ok
    private let myPeerID: MCPeerID

    private lazy var session: MCSession = {
        let s = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self
        return s
    }()

    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?

    // MARK: - Init

    init(sessionID: String = UUID().uuidString,
         deviceName: String = UIDevice.current.name) {
        self.sessionID = sessionID
        // Truncate device names — MCPeerID is capped at 63 bytes and
        // the user's "Marketing's iPhone 17 Pro Max" can sail past.
        let trimmed = String(deviceName.prefix(40))
        self.myPeerID = MCPeerID(displayName: trimmed.isEmpty ? "Player" : trimmed)
        super.init()
    }

    deinit {
        // teardown is intentionally NOT called from deinit — MainActor
        // isolation makes that complex. Callers should leave() before
        // releasing the session.
    }

    // MARK: - Host flow

    /// Begin advertising as a discoverable host. Guests in range will
    /// see this peer with `discoveryInfo["session"] == sessionID`.
    func host() {
        role = .host
        state = .searching
        let info = ["session": sessionID]
        let a = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: info, serviceType: serviceType)
        a.delegate = self
        advertiser = a
        a.startAdvertisingPeer()
    }

    // MARK: - Guest flow

    /// Begin browsing for the host matching `sessionID`. We auto-invite
    /// the first peer whose discoveryInfo matches — no confirmation UI,
    /// since the user just deliberately scanned the QR.
    func join(sessionID joinID: String) {
        role = .guest
        state = .searching
        let b = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        b.delegate = self
        browser = b
        b.startBrowsingForPeers()
        // We treat the scanned ID as authoritative — only matching
        // advertisers should be invited. Validation happens in the
        // browser delegate.
        _expectedSessionID = joinID
    }
    private var _expectedSessionID: String = ""

    // MARK: - Local submission

    /// Record the local player's ratings and ship them to the peer.
    /// Caller transitions UI to "waiting" on `.submittedLocally`.
    func submit(_ submission: Submission) {
        localSubmission = submission
        send(submission)
        evaluateProgress()
    }

    // MARK: - Teardown

    func leave() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        session.disconnect()
        state = .idle
        peerSubmission = nil
        peerDisplayName = nil
    }

    // MARK: - Internals

    private func send(_ submission: Submission) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(submission) else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            state = .failed(NSLocalizedString("coach.error_send_failed", comment: ""))
        }
    }

    private func evaluateProgress() {
        if localSubmission != nil && peerSubmission != nil {
            state = .bothSubmitted
        } else if localSubmission != nil {
            state = .submittedLocally
        }
    }
}

// MARK: - MCSessionDelegate

extension CoachSession: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange peerState: MCSessionState) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch peerState {
            case .connected:
                self.peerDisplayName = peerID.displayName
                self.state = .connected
                // Once connected we stop advertising/browsing so a
                // third device can't gatecrash mid-session.
                self.advertiser?.stopAdvertisingPeer()
                self.browser?.stopBrowsingForPeers()
            case .connecting:
                self.state = .connecting
            case .notConnected:
                if self.state != .bothSubmitted {
                    self.state = .disconnected
                }
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let decoded = try? JSONDecoder().decode(Submission.self, from: data) else { return }
        Task { @MainActor [weak self] in
            self?.peerSubmission = decoded
            self?.evaluateProgress()
        }
    }

    // Unused stream / resource callbacks — required by protocol.
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension CoachSession: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { invitationHandler(false, nil); return }
            // Auto-accept first invite — the guest only knew to invite
            // because they scanned our QR, which is implicit consent.
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor [weak self] in
            self?.state = .failed(NSLocalizedString("coach.error_advertise_failed", comment: ""))
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension CoachSession: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard info?["session"] == self._expectedSessionID else { return }
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 15)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // No-op for v1 — disconnect handling is on the MCSession side.
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor [weak self] in
            self?.state = .failed(NSLocalizedString("coach.error_browse_failed", comment: ""))
        }
    }
}
