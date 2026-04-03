import SwiftUI
import UIKit

struct ImageCropPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true  // Enables native square crop
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImageCropPicker

        init(_ parent: ImageCropPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            // Use the cropped image if available, fall back to original
            if let edited = info[.editedImage] as? UIImage {
                parent.onImageSelected(edited)
            } else if let original = info[.originalImage] as? UIImage {
                parent.onImageSelected(original)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}
