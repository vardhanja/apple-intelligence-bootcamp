//
//  ImagePicker.swift
//  05_Custom-Model-CreateML
//
//  Created by Ashok Vardhan Jangeti on 03/11/25.
//


import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
  @Binding var image: UIImage?
  @Binding var sourceType: UIImagePickerController.SourceType
  @Environment(\.presentationMode) var presentationMode

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.delegate = context.coordinator
    picker.sourceType = sourceType
    // Allow editing (shows a crop box) when the user opens the camera.
    // UIImagePickerController provides a simple square crop UI when allowsEditing is true.
    picker.allowsEditing = (sourceType == .camera)
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let parent: ImagePicker

    init(_ parent: ImagePicker) {
      self.parent = parent
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
      // Prefer the edited (cropped) image if available, otherwise fall back to original
      if let edited = info[.editedImage] as? UIImage {
        parent.image = edited
      } else if let uiImage = info[.originalImage] as? UIImage {
        parent.image = uiImage
      }
      parent.presentationMode.wrappedValue.dismiss()
    }
  }
}