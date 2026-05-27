import Foundation
import MetricKit
import os

/// Lightweight crash/hang/disk-write reporter built on Apple's MetricKit.
///
/// During TestFlight we want crash + hang signals without taking a SPM
/// dependency on Sentry/Firebase Crashlytics. MetricKit hands us aggregated
/// diagnostics on a 24h cadence (or on-demand on macOS-attached debug runs).
///
/// Reports are persisted to the app's caches directory so they're available
/// after the next launch, and surfaced in the unified log under the
/// subsystem "CourtIQ.diagnostics" so beta builds can inspect them via
/// Console.app or Xcode → Devices.
@MainActor
final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReporter()

    private let logger = Logger(subsystem: "CourtIQ.diagnostics", category: "MetricKit")
    private let queue = DispatchQueue(label: "CourtIQ.crash-reporter", qos: .utility)

    private override init() { super.init() }

    /// Subscribe at app launch (CourtIQApp.init).
    func start() {
        MXMetricManager.shared.add(self)
        logger.info("CrashReporter subscribed")
    }

    // MARK: - MXMetricManagerSubscriber

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        // Aggregate metrics — useful but not crash-relevant.
        // Dump to log only.
        for payload in payloads {
            let json = String(data: payload.jsonRepresentation(), encoding: .utf8) ?? "—"
            log("metric", json: json)
        }
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            handleDiagnosticPayload(payload)
        }
    }

    // MARK: - Diagnostic handling

    nonisolated private func handleDiagnosticPayload(_ payload: MXDiagnosticPayload) {
        let json = String(data: payload.jsonRepresentation(), encoding: .utf8) ?? "—"

        let crashCount = payload.crashDiagnostics?.count ?? 0
        let hangCount = payload.hangDiagnostics?.count ?? 0
        let cpuExceptionCount = payload.cpuExceptionDiagnostics?.count ?? 0
        let diskWriteCount = payload.diskWriteExceptionDiagnostics?.count ?? 0

        log("diagnostic",
            summary: "crashes=\(crashCount) hangs=\(hangCount) cpu=\(cpuExceptionCount) disk=\(diskWriteCount)",
            json: json)

        // Persist to caches so we can read the latest diagnostic on next launch.
        persistLatest(json: json)
    }

    nonisolated private func log(_ kind: String, summary: String? = nil, json: String) {
        let summaryLine = summary.map { " [\($0)]" } ?? ""
        // Print full JSON only to file/log — could be large.
        #if DEBUG
        print("[CrashReporter] \(kind)\(summaryLine)")
        #endif
        Task { @MainActor in
            self.logger.notice("\(kind, privacy: .public)\(summaryLine, privacy: .public)")
        }
        _ = json // available if we later wire to a remote sink
    }

    nonisolated private func persistLatest(json: String) {
        queue.async {
            guard let dir = FileManager.default.urls(for: .cachesDirectory,
                                                     in: .userDomainMask).first else { return }
            let url = dir.appendingPathComponent("courtiq-last-diagnostic.json")
            try? json.data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }

    /// Returns the most recently captured MetricKit diagnostic, if any.
    /// Useful for an in-app "recent diagnostic" view during beta.
    static func lastDiagnosticJSON() -> String? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory,
                                                 in: .userDomainMask).first else { return nil }
        let url = dir.appendingPathComponent("courtiq-last-diagnostic.json")
        return try? String(contentsOf: url, encoding: .utf8)
    }
}
