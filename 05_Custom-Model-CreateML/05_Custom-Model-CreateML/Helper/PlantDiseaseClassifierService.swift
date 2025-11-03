//
//  PlantDiseaseClassifierService.swift
//  05_Custom-Model-CreateML
//
//  Created by Ashok Vardhan Jangeti on 03/11/25.
//


import SwiftUI
import Vision
import CoreML

class PlantDiseaseClassifierService {
  private let model: VNCoreMLModel
  private let coreMLModel: MLModel

  init() {
    // Try loading the model with fallback compute unit configurations.
    let computeOptions: [MLComputeUnits] = [.cpuOnly, .cpuAndGPU, .all]
    var lastError: Error?
    var loadedVNModel: VNCoreMLModel? = nil
    var loadedCoreMLModel: MLModel? = nil

    for units in computeOptions {
      let config = MLModelConfiguration()
      config.computeUnits = units
      do {
        let container = try PlantDiseaseClassifier(configuration: config)
        let mlModel = container.model
        let vnModel = try VNCoreMLModel(for: mlModel)
        loadedVNModel = vnModel
        loadedCoreMLModel = mlModel
        print("PlantDiseaseClassifier loaded with computeUnits: \(units)")
        break
      } catch {
        lastError = error
        print("Failed to load PlantDiseaseClassifier with computeUnits=\(units): \(error.localizedDescription)")
      }
    }

    // If we couldn't load via the generated model class, try to load the compiled
    // or source .mlmodel directly from the app bundle (helps when model wasn't
    // included in the target or wasn't compiled properly by Xcode).
    if loadedVNModel == nil || loadedCoreMLModel == nil {
      // List a few bundle entries for debugging
      if let resourcePath = Bundle.main.resourcePath {
        do {
          let entries = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
          print("Bundle resources (first 50): \(Array(entries.prefix(50)))")
        } catch {
          print("Failed to list bundle resources: \(error.localizedDescription)")
        }
      }

      // Try to load compiled model (.mlmodelc)
      if let compiledURL = Bundle.main.url(forResource: "PlantDiseaseClassifier", withExtension: "mlmodelc") {
        do {
          let mlModel = try MLModel(contentsOf: compiledURL)
          let vnModel = try VNCoreMLModel(for: mlModel)
          loadedVNModel = loadedVNModel ?? vnModel
          loadedCoreMLModel = loadedCoreMLModel ?? mlModel
          print("Loaded compiled model from bundle at: \(compiledURL.path)")
        } catch {
          lastError = error
          print("Failed to load compiled model at \(compiledURL.path): \(error.localizedDescription)")
        }
      } else if let modelURL = Bundle.main.url(forResource: "PlantDiseaseClassifier", withExtension: "mlmodel") {
        // If only the raw .mlmodel is present, try compiling it at runtime (slow).
        do {
          let compiledURL = try MLModel.compileModel(at: modelURL)
          let mlModel = try MLModel(contentsOf: compiledURL)
          let vnModel = try VNCoreMLModel(for: mlModel)
          loadedVNModel = loadedVNModel ?? vnModel
          loadedCoreMLModel = loadedCoreMLModel ?? mlModel
          print("Compiled and loaded model from source .mlmodel at: \(modelURL.path)")
        } catch {
          lastError = error
          print("Failed to compile/load .mlmodel at \(modelURL.path): \(error.localizedDescription)")
        }
      } else {
        print("No PlantDiseaseClassifier.mlmodel or .mlmodelc found in bundle. Ensure the model is added to the app target.")
      }
    }

    if let finalVN = loadedVNModel, let finalCore = loadedCoreMLModel {
      self.model = finalVN
      self.coreMLModel = finalCore
    } else {
      // Provide an actionable error message to make debugging easier.
      let message = "Failed to load PlantDiseaseClassifier model. Last error: \(lastError?.localizedDescription ?? "unknown")\n" +
                    "Try cleaning the build folder, ensuring the .mlmodel is in the app target, and rebuilding in Xcode."
      fatalError(message)
    }
  }

  func classify(image: UIImage, completion: @escaping (String?, Float?) -> Void) {
    // 2. Convert UIImage to CIImage
    guard let ciImage = CIImage(image: image) else {
      completion(nil, nil)
      return
    }

    // 3. Create a VNCoreMLRequest with the model
    let request = VNCoreMLRequest(model: model) { request, error in
      if let error = error {
        print("Error during classification (Vision): \(error.localizedDescription)")

        // If Vision fails with an inference-context error, try direct Core ML prediction.
        if error.localizedDescription.lowercased().contains("inference context") ||
           error.localizedDescription.lowercased().contains("inferencecontext") ||
           error.localizedDescription.lowercased().contains("could not create inference") {
          print("Attempting Core ML fallback prediction (direct MLModel) since Vision failed")
          if let (label, conf) = self.coreMLPredict(from: image) {
            completion(label, conf)
            return
          }
        }

        completion(nil, nil)
        return
      }

      // 4. Handle the classification results
      guard let results = request.results as? [VNClassificationObservation] else {
        print("No results found")
        completion(nil, nil)
        return
      }

      // 5. Find the top result based on confidence
      let topResult = results.max(by: { a, b in a.confidence < b.confidence })
      guard let bestResult = topResult else {
        print("No top result found")
        completion(nil, nil)
        return
      }

      // 6. Pass the top result to the completion handler
      completion(bestResult.identifier, bestResult.confidence)
    }

    // Prefer center-crop scaling to match many image models
    request.imageCropAndScaleOption = .centerCrop

    // 7. Create a VNImageRequestHandler
    let handler = VNImageRequestHandler(ciImage: ciImage)

    // 8. Perform the request on a background thread
    DispatchQueue.global(qos: .userInteractive).async {
      do {
        try handler.perform([request])
      } catch {
        print("Failed to perform classification (Vision handler): \(error.localizedDescription)")
        // Try Core ML fallback
        if let (label, conf) = self.coreMLPredict(from: image) {
          DispatchQueue.main.async {
            completion(label, conf)
          }
        } else {
          DispatchQueue.main.async {
            completion(nil, nil)
          }
        }
      }
    }
  }

  // MARK: - Core ML fallback prediction
  private func coreMLPredict(from uiImage: UIImage) -> (String, Float)? {
    // Resize image to model expected size if possible (many models use 224x224)
    let targetSize = CGSize(width: 224, height: 224)
    UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
    uiImage.draw(in: CGRect(origin: .zero, size: targetSize))
    let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    guard let image = resizedImage, let pxBuffer = pixelBuffer(from: image, size: targetSize) else {
      print("Failed to create pixel buffer for Core ML fallback")
      return nil
    }

    // Determine input feature name
    guard let inputName = coreMLModel.modelDescription.inputDescriptionsByName.keys.first else {
      print("Model has no input descriptions")
      return nil
    }

    let featureValue = MLFeatureValue(pixelBuffer: pxBuffer)
    let input = try? MLDictionaryFeatureProvider(dictionary: [inputName: featureValue])

    do {
      guard let input = input else { return nil }
      let prediction = try coreMLModel.prediction(from: input)

      // Try to extract class label (common key: 'classLabel')
      if let classLabel = prediction.featureValue(for: "classLabel")?.stringValue {
        var confidence: Float = 0.0
        // Try classLabelProbs
        if let probs = prediction.featureValue(for: "classLabelProbs")?.dictionaryValue as? [String: Double], let conf = probs[classLabel] {
          confidence = Float(conf)
        } else if let probsAny = prediction.featureValue(for: "classLabelProbs")?.dictionaryValue as? [String: Any], let confAny = probsAny[classLabel] as? Double {
          confidence = Float(confAny)
        }
        return (classLabel, confidence)
      }

      // Fallback: inspect output probabilities and pick top
      for (name, desc) in coreMLModel.modelDescription.outputDescriptionsByName {
        if desc.type == .dictionary {
          if let dict = prediction.featureValue(for: name)?.dictionaryValue as? [String: Double] {
            if let (label, conf) = dict.max(by: { $0.value < $1.value }) {
              return (label, Float(conf))
            }
          }
          if let dictAny = prediction.featureValue(for: name)?.dictionaryValue as? [String: Any] {
            var bestLabel: String? = nil
            var bestValue: Double = -Double.greatestFiniteMagnitude
            for (k, v) in dictAny {
              if let dv = v as? Double, dv > bestValue {
                bestValue = dv
                bestLabel = k
              }
            }
            if let label = bestLabel {
              return (label, Float(bestValue))
            }
          }
        }
      }

      print("Core ML prediction succeeded but no class label found")
      return nil

    } catch {
      print("Core ML prediction failed: \(error.localizedDescription)")
      return nil
    }
  }

  private func pixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
    guard status == kCVReturnSuccess, let px = pixelBuffer else {
      return nil
    }

    CVPixelBufferLockBaseAddress(px, CVPixelBufferLockFlags(rawValue: 0))
    let pxData = CVPixelBufferGetBaseAddress(px)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: pxData,
                                  width: Int(size.width),
                                  height: Int(size.height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(px),
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
      CVPixelBufferUnlockBaseAddress(px, CVPixelBufferLockFlags(rawValue: 0))
      return nil
    }

    guard let cgImage = image.cgImage else {
      CVPixelBufferUnlockBaseAddress(px, CVPixelBufferLockFlags(rawValue: 0))
      return nil
    }

    context.draw(cgImage, in: CGRect(origin: .zero, size: size))
    CVPixelBufferUnlockBaseAddress(px, CVPixelBufferLockFlags(rawValue: 0))
    return px
  }
}