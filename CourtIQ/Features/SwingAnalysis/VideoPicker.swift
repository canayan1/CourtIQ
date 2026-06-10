import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// SwiftUI wrapper around `UIImagePickerController` that lets the user EITHER
/// record a short video with the camera OR pick one from the photo library,
/// depending on the passed-in `sourceType`. Returns the recorded/picked video
/// file URL via `onPicked`. Camera + microphone Info.plist usage strings are
/// supplied by the host app.
struct VideoPicker: UIViewControllerRepresentable {
    /// `.camera` to record, `.photoLibrary` to pick an existing clip.
    let sourceType: UIImagePickerController.SourceType
    /// Delivers the local file URL of the chosen video, or `nil` if cancelled.
    let onPicked: (URL?) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Guard against simulators / devices without a camera: fall back to
        // the library so we never present an unusable controller.
        if sourceType == .camera, UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .video
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.mediaTypes = [UTType.movie.identifier]
        picker.videoMaximumDuration = 20
        picker.videoQuality = .typeHigh
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: VideoPicker

        init(_ parent: VideoPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let url = info[.mediaURL] as? URL
            parent.onPicked(url)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onPicked(nil)
            parent.dismiss()
        }
    }
}
