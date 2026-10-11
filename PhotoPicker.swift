import SwiftUI
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        init(_ parent: PhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController,
                    didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            results.first?.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                DispatchQueue.main.async { self.parent.image = obj as? UIImage }
            }
        }
    }
}
