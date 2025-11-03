//
//  PlantDiseaseDetectionViewModel.swift
//  05_Custom-Model-CreateML
//
//  Created by Ashok Vardhan Jangeti on 03/11/25.
//


import SwiftUI
import Combine

class PlantDiseaseDetectionViewModel: ObservableObject {
  @Published var image: UIImage?
  @Published var disease: String?
  @Published var accuracy: String?

  private let classifier = PlantDiseaseClassifierService()

  func classifyImage() {
    if let image = self.image {
      // Resize the image before classification
      let resizedImage = resizeImage(image)
      DispatchQueue.global(qos: .userInteractive).async {
        self.classifier.classify(image: resizedImage ?? image) { [weak self] disease, confidence in
          // Update the published properties on the main thread
          DispatchQueue.main.async {
            self?.disease = disease ?? "Unknown"
            self?.accuracy = String(format: "%.2f%%", (confidence ?? 0) * 100.0)
          }
        }
      }
    }
  }

  func reset() {
    DispatchQueue.main.async {
      self.image = nil
      self.disease = nil
      self.accuracy = nil
    }
  }

  private func resizeImage(_ image: UIImage) -> UIImage? {
    UIGraphicsBeginImageContext(CGSize(width: 224, height: 224))
    image.draw(in: CGRect(x: 0, y: 0, width: 224, height: 224))
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return resizedImage
  }
}
