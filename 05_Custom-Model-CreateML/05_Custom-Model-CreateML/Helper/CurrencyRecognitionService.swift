//
//  CurrencyRecognitionServiceError.swift
//  05_Custom-Model-CreateML
//
//  Created by Ashok Vardhan Jangeti on 03/11/25.
//


import UIKit
import Vision
import CoreML

enum CurrencyRecognitionServiceError: Error {
  case modelLoadFailed(String)
  case pixelBufferCreationFailed
  case classificationFailed
}

class CurrencyRecognitionService {
  private(set) var mlModel: MLModel
  private(set) var vnModel: VNCoreMLModel
  private let cache = NSCache<NSString, NSArray>()
  private(set) var computeUnits: MLComputeUnits

  init(preferredComputeUnits: MLComputeUnits = .cpuOnly) throws {
    self.computeUnits = preferredComputeUnits

    let attempts: [MLComputeUnits] = [preferredComputeUnits, .cpuOnly, .cpuAndGPU, .all]
    var lastError: Error?
    var loadedML: MLModel? = nil
    var loadedVN: VNCoreMLModel? = nil

    for cu in attempts {
      do {
        let config = MLModelConfiguration()
        config.computeUnits = cu

        // Try to load model by name from bundle (compile if needed)
        if let compiledURL = Bundle.main.url(forResource: "CurrencyRecognition", withExtension: "mlmodelc") {
          let m = try MLModel(contentsOf: compiledURL, configuration: config)
          let v = try VNCoreMLModel(for: m)
          loadedML = m
          loadedVN = v
          self.computeUnits = cu
          break
        } else if let modelURL = Bundle.main.url(forResource: "CurrencyRecognition", withExtension: "mlmodel") {
          let compiledURL = try MLModel.compileModel(at: modelURL)
          let m = try MLModel(contentsOf: compiledURL, configuration: config)
          let v = try VNCoreMLModel(for: m)
          loadedML = m
          loadedVN = v
          self.computeUnits = cu
          break
        }
      } catch {
        lastError = error
        appLog("Failed loading CurrencyRecognition with computeUnits=\(cu): \(error.localizedDescription)")
      }
    }

    if let finalML = loadedML, let finalVN = loadedVN {
      self.mlModel = finalML
      self.vnModel = finalVN
      // Debug: print model description (outputs/inputs) to help verify class labels are present
      appLog("[CurrencyRecognition] Loaded MLModel: \(self.mlModel.modelDescription)")
    } else {
      throw CurrencyRecognitionServiceError.modelLoadFailed(lastError?.localizedDescription ?? "unknown")
    }
  }

  func setComputeUnits(_ units: MLComputeUnits) throws {
    if units == computeUnits { return }
    let config = MLModelConfiguration()
    config.computeUnits = units
    // Try loading compiled model with new config
    if let compiledURL = Bundle.main.url(forResource: "CurrencyRecognition", withExtension: "mlmodelc") {
      let m = try MLModel(contentsOf: compiledURL, configuration: config)
      let v = try VNCoreMLModel(for: m)
      self.mlModel = m
      self.vnModel = v
      self.computeUnits = units
      cache.removeAllObjects()
      return
    }
    // Try compiling source .mlmodel
    if let modelURL = Bundle.main.url(forResource: "CurrencyRecognition", withExtension: "mlmodel") {
      let compiledURL = try MLModel.compileModel(at: modelURL)
      let m = try MLModel(contentsOf: compiledURL, configuration: config)
      let v = try VNCoreMLModel(for: m)
      self.mlModel = m
      self.vnModel = v
      self.computeUnits = units
      cache.removeAllObjects()
      return
    }
    throw CurrencyRecognitionServiceError.modelLoadFailed("Model file not found in bundle")
  }

  func classify(image: UIImage, completion: @escaping (String?, Float?) -> Void) {
    classifyTopK(image: image, topK: 1) { results, _ in
      if let r = results?.first {
        completion(r.label, r.confidence)
      } else {
        completion(nil, nil)
      }
    }
  }

  func classifyTopK(image: UIImage, topK: Int = 3, confidenceThreshold: Float = 0.0, completion: @escaping (_ results: [(label: String, confidence: Float)]?, _ error: Error?) -> Void) {
    guard let key = cacheKey(for: image) else {
      completion(nil, CurrencyRecognitionServiceError.pixelBufferCreationFailed)
      return
    }

    if let cached = cache.object(forKey: key) as? [[String: Any]], !cached.isEmpty {
      let mapped = cached.prefix(topK).compactMap { dict -> (label: String, confidence: Float)? in
        guard let l = dict["label"] as? String else { return nil }
        // confidence may have been stored as Float or Double; handle both
        if let cFloat = dict["confidence"] as? Float {
          return (label: l, confidence: cFloat)
        } else if let cDouble = dict["confidence"] as? Double {
          return (label: l, confidence: Float(cDouble))
        } else if let cNumber = dict["confidence"] as? NSNumber {
          return (label: l, confidence: cNumber.floatValue)
        }
        return nil
      }
      completion(mapped, nil)
      return
    }

    guard let pixelBuffer = pixelBuffer(from: image) else {
      completion(nil, CurrencyRecognitionServiceError.pixelBufferCreationFailed)
      return
    }

    let request = VNCoreMLRequest(model: vnModel) { [weak self] request, error in
      guard let self = self else { return }
      if let err = error {
        appLog("Vision classification error: \(err.localizedDescription)")
        self.directPredict(pixelBuffer: pixelBuffer, topK: topK, confidenceThreshold: confidenceThreshold, completion: completion)
        return
      }

      guard let observations = request.results as? [VNClassificationObservation] else {
        completion(nil, CurrencyRecognitionServiceError.classificationFailed)
        return
      }

      // Build array of labeled tuples and sort by confidence
      var top = observations.prefix(topK).map { (label: $0.identifier, confidence: Float($0.confidence)) }
      top.sort { $0.confidence > $1.confidence }
      // Do not coerce labels to "Unknown" here; always return model labels
      let final: [(label: String, confidence: Float)] = top.map { (label: $0.label, confidence: $0.confidence) }

      // Cache in simple serializable form
      let cacheArray = final.map { ["label": $0.label, "confidence": $0.confidence] }
      self.cache.setObject(cacheArray as NSArray, forKey: key)

      // Debug log: show top predictions
      appLog("[CurrencyRecognition] top results: \(final.map { ($0.label, $0.confidence) })")

      completion(final, nil)
    }

    request.imageCropAndScaleOption = .centerCrop
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        appLog("VNImageRequestHandler perform error: \(error.localizedDescription)")
        self.directPredict(pixelBuffer: pixelBuffer, topK: topK, confidenceThreshold: confidenceThreshold, completion: completion)
      }
    }
  }

  func classifyWithTTA(image: UIImage, topK: Int = 3, confidenceThreshold: Float = 0.0, augmentationSet: [UIImage]? = nil, completion: @escaping (_ results: [(label: String, confidence: Float)]?, _ error: Error?) -> Void) {
    let images = augmentationSet ?? ttaAugmentations(for: image)
    var accum: [String: Float] = [:]
    let group = DispatchGroup()
    var anyError: Error?

    for img in images {
      group.enter()
      classifyTopK(image: img, topK: topK, confidenceThreshold: 0.0) { results, error in
        if let err = error { anyError = err }
        if let results = results {
          for r in results {
            accum[r.label, default: 0.0] += r.confidence
          }
        }
        group.leave()
      }
    }

    group.notify(queue: .main) {
      if anyError != nil && accum.isEmpty {
        completion(nil, anyError)
        return
      }
      let count = Float(images.count)
      // Create labeled tuples and sort
      var averaged: [(label: String, confidence: Float)] = accum.map { (label: $0.key, confidence: $0.value / count) }
      averaged.sort { $0.confidence > $1.confidence }
      let top = Array(averaged.prefix(topK))
      // Return averaged scores with original labels
      let final: [(label: String, confidence: Float)] = top.map { (label: $0.label, confidence: $0.confidence) }
      appLog("[CurrencyRecognition][TTA] averaged results: \(final.map { ($0.label, $0.confidence) })")
      completion(final, nil)
    }
  }

  // MARK: - Direct Core ML fallback
  private func directPredict(pixelBuffer: CVPixelBuffer, topK: Int, confidenceThreshold: Float, completion: @escaping (_ results: [(label: String, confidence: Float)]?, _ error: Error?) -> Void) {
    do {
      guard let inputName = mlModel.modelDescription.inputDescriptionsByName.keys.first else {
        completion(nil, CurrencyRecognitionServiceError.classificationFailed)
        return
      }
      let input = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(pixelBuffer: pixelBuffer)])
      let out = try mlModel.prediction(from: input)

      if let probDict = out.featureValue(for: "classLabelProbs")?.dictionaryValue as? [String: Double] {
        // Build an array of labeled tuples, sort by confidence, then take topK
        var mapped = probDict.map { (label: $0.key, confidence: Float($0.value)) }
        mapped.sort { $0.confidence > $1.confidence }
        let top = Array(mapped.prefix(topK)) // array of (label: String, confidence: Float)
        // Apply confidence threshold and keep labeled tuple form for the caller
        let final: [(label: String, confidence: Float)] = top.map { (label: $0.label, confidence: $0.confidence) }
        print("[CurrencyRecognition][Direct] directPredict results: \(final.map { ($0.label, $0.confidence) })")
        completion(final, nil)
        return
      }

      if let label = out.featureValue(for: "classLabel")?.stringValue {
        completion([(label: label, confidence: Float(1.0))], nil)
        return
      }

      completion(nil, CurrencyRecognitionServiceError.classificationFailed)
    } catch {
      completion(nil, error)
    }
  }

  // MARK: - Helpers
  private func ttaAugmentations(for image: UIImage) -> [UIImage] {
    var results: [UIImage] = [image]
    if let r90 = image.rotated(by: 90) { results.append(r90) }
    if let r180 = image.rotated(by: 180) { results.append(r180) }
    if let r270 = image.rotated(by: 270) { results.append(r270) }
    if let f = image.flippedHorizontally() { results.append(f) }
    return results
  }

  private func cacheKey(for image: UIImage) -> NSString? {
    guard let data = image.pngData() else { return nil }
    var hasher = Hasher()
    hasher.combine(data.count)
    hasher.combine(data.prefix(64))
    let h = String(hasher.finalize())
    return NSString(string: h)
  }

  private func pixelBuffer(from image: UIImage, size: CGSize = CGSize(width: 224, height: 224)) -> CVPixelBuffer? {
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
    image.draw(in: CGRect(origin: .zero, size: size))
    guard let resized = UIGraphicsGetImageFromCurrentImageContext() else {
      UIGraphicsEndImageContext()
      return nil
    }
    UIGraphicsEndImageContext()
    guard let cgImage = resized.cgImage else { return nil }

    let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
    var pxbuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attrs, &pxbuffer)
    guard status == kCVReturnSuccess, let buffer = pxbuffer else { return nil }

    CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
    guard let pxdata = CVPixelBufferGetBaseAddress(buffer) else {
      CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
      return nil
    }

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(data: pxdata,
                                  width: Int(size.width),
                                  height: Int(size.height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
      CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
      return nil
    }

    context.draw(cgImage, in: CGRect(origin: .zero, size: size))
    CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
    return buffer
  }
}

private extension UIImage {
  func rotated(by degrees: CGFloat) -> UIImage? {
    let radians = degrees * CGFloat.pi / 180
    var newSize = CGRect(origin: .zero, size: size).applying(CGAffineTransform(rotationAngle: radians)).integral.size
    newSize.width = floor(newSize.width); newSize.height = floor(newSize.height)
    UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
    guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
    ctx.translateBy(x: newSize.width/2, y: newSize.height/2)
    ctx.rotate(by: radians)
    draw(in: CGRect(x: -size.width/2, y: -size.height/2, width: size.width, height: size.height))
    let img = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return img
  }

  func flippedHorizontally() -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, scale)
    guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
    ctx.translateBy(x: size.width, y: 0)
    ctx.scaleBy(x: -1.0, y: 1.0)
    draw(in: CGRect(origin: .zero, size: size))
    let img = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return img
  }
}
