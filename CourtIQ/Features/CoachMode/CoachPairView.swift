import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins

/// Entry surface for Coach Mode pairing. Two paths:
///   • **Host** generates a QR code containing the ephemeral session ID
///     and starts MC advertising. Stays on screen until a guest connects.
///   • **Guest** opens the camera, scans the host's QR, and starts MC
///     browsing for the matching advertiser.
///
/// Once a peer is connected we hand off to `CoachQuickLogView` so both
/// players capture ratings independently.
struct CoachPairView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var lang: LanguageManager
    @StateObject private var session = CoachSession()

    /// Toggles between landing / hosting / scanning. Driven by user
    /// choice rather than CoachSession.state because pairing-stage
    /// transitions are local UI affairs.
    enum PairingStage {
        case landing       // choose host or scan
        case hosting       // show our QR + wait
        case scanning      // camera open
        case inMatch       // hand off to CoachQuickLogView
    }
    @State private var stage: PairingStage = .landing

    var body: some View {
        NavigationStack {
            content
                .background(AppPalette.cream)
                .navigationTitle(lang.t("coach.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(lang.t("common.cancel")) {
                            session.leave()
                            dismiss()
                        }
                    }
                }
                .onChange(of: session.state) { _, new in
                    // As soon as the peer connection lands, advance into
                    // the shared rating capture.
                    if new == .connected {
                        stage = .inMatch
                    }
                }
        }
        .interactiveDismissDisabled(stage == .inMatch)
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .landing:
            landingView
        case .hosting:
            hostingView
        case .scanning:
            ScannerView(isPresented: Binding(
                get: { stage == .scanning },
                set: { if !$0 { stage = .landing } }
            )) { scanned in
                handleScannedPayload(scanned)
            }
        case .inMatch:
            CoachQuickLogView(session: session)
        }
    }

    // MARK: - Landing

    private var landingView: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 12)

            VStack(spacing: 14) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(AppPalette.clay)
                Text(lang.t("coach.headline"))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(lang.t("coach.subhead"))
                    .font(.subheadline)
                    .foregroundStyle(AppPalette.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            VStack(spacing: 12) {
                Button {
                    session.host()
                    stage = .hosting
                } label: {
                    Label(lang.t("coach.host_cta"), systemImage: "qrcode")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppPalette.clay)

                Button {
                    stage = .scanning
                } label: {
                    Label(lang.t("coach.scan_cta"), systemImage: "qrcode.viewfinder")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
                .tint(AppPalette.clay)
            }
            .padding(.horizontal, 28)

            Spacer()
        }
    }

    // MARK: - Hosting

    private var hostingView: some View {
        VStack(spacing: 22) {
            Spacer().frame(height: 4)

            Text(lang.t("coach.host_show_qr"))
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            qrImage(for: pairingPayload(sessionID: session.sessionID))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 240, height: 240)
                .padding(16)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

            statusBadge

            Spacer()
        }
    }

    private var statusBadge: some View {
        Group {
            switch session.state {
            case .searching:
                Label(lang.t("coach.waiting_for_partner"), systemImage: "antenna.radiowaves.left.and.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.inkSoft)
            case .connecting:
                ProgressView(lang.t("coach.connecting"))
            case .connected:
                Label(lang.t("coach.partner_connected"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(AppPalette.moss)
            case .failed(let msg):
                Label(msg, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppPalette.alert)
            default:
                EmptyView()
            }
        }
        .padding(.top, 6)
    }

    // MARK: - QR generation + payload

    /// Payload encoded into the host's QR. Stable URL-style format so a
    /// future deep-link flow (v1.2 Phase 2) can use the same string.
    private func pairingPayload(sessionID: String) -> String {
        "courtiq://coach?session=\(sessionID)"
    }

    private func qrImage(for string: String) -> Image {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let outputImage = filter.outputImage else {
            return Image(systemName: "qrcode")
        }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaled = outputImage.transformed(by: transform)
        if let cgImage = context.createCGImage(scaled, from: scaled.extent) {
            return Image(decorative: cgImage, scale: 1.0)
        }
        return Image(systemName: "qrcode")
    }

    // MARK: - Scan handler

    private func handleScannedPayload(_ payload: String) {
        // Accept either `courtiq://coach?session=<uuid>` or a bare UUID.
        let id: String
        if let comp = URLComponents(string: payload),
           comp.scheme == "courtiq",
           comp.host == "coach",
           let sid = comp.queryItems?.first(where: { $0.name == "session" })?.value {
            id = sid
        } else {
            id = payload
        }
        session.join(sessionID: id)
        stage = .hosting   // reuse hosting view; statusBadge shows progress
    }
}

// MARK: - Camera scanner (AVFoundation, minimal)

/// Minimal viewfinder wrapped in a SwiftUI view. Scans QR (and any
/// machineReadableObject that AVFoundation recognises) and emits the
/// first detected payload back through `onScan`. Designed to be
/// presented with a SwiftUI binding; closes itself when scan succeeds.
struct ScannerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onScan = { payload in
            onScan(payload)
            isPresented = false
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession.canAddInput(input) else {
            return
        }
        captureSession.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(output) else { return }
        captureSession.addOutput(output)
        output.metadataObjectTypes = [.qr]
        output.setMetadataObjectsDelegate(self, queue: .main)

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.frame = view.layer.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
            captureSession.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [captureSession] in
            if captureSession.isRunning { captureSession.stopRunning() }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let payload = object.stringValue else { return }
        captureSession.stopRunning()
        onScan?(payload)
    }
}
