//
//  ContentView.swift
//  06_3rd-party-ondevice-models
//
//  Created by Ashok Vardhan Jangeti on 10/11/25.
//

import SwiftUI
import PhotosUI
import Vision
import CoreML

struct ClassificationResult: Hashable, Identifiable {
  let id = UUID()
  var label: String
  var confidence: Float
}

struct ContentView: View {
  // Use a typed enum for available models (keeps UI the same but provides type-safety)
  enum ModelType: String, CaseIterable, Identifiable {
    case resnet50 = "resnet50"
    case mobilenetv2 = "mobilenetv2"
    case fastvit_t12 = "fastvit_t12"
    case yolov8x_cls_int8 = "yolov8x-cls-int8"

    var id: String { rawValue }

    var display: String {
      switch self {
      case .resnet50: return "ResNet50"
      case .mobilenetv2: return "MobileNetV2"
      case .fastvit_t12: return "FastViT-T12"
      case .yolov8x_cls_int8: return "YOLOv8x-cls-int"
      }
    }
  }

  @State private var selectedImage: PhotosPickerItem?
  @State private var image: Image?
  @State private var cgImage: CGImage?
  @State private var classResults: [ClassificationResult] = []
  @State private var selectedModelKey: ModelType = .resnet50
  @State private var isClassifying: Bool = false

  private func loadLabelsNear(_ url: URL) -> [String]? {
    let fm = FileManager.default
    let searchNames = ["classes_imagenet.txt"]

    let folder = url.deletingLastPathComponent()
    // Check common filenames directly in the same folder
    for name in searchNames {
      let candidate = folder.appendingPathComponent(name)
      if fm.fileExists(atPath: candidate.path) {
        if name.hasSuffix(".txt") {
          if let s = try? String(contentsOf: candidate, encoding: .utf8) {
            let lines = s.split(whereSeparator: { $0.isNewline }).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if !lines.isEmpty { return lines }
          }
        } else if name.hasSuffix(".json") {
          if let data = try? Data(contentsOf: candidate), let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
            if !arr.isEmpty { return arr }
          }
        }
      }
    }

    // As a fallback, search a couple of levels deep under the folder for these filenames (covers .mlpackage structure)
    // NOTE: allow descending into package directories (don't skip package descendants) so we can find labels inside .mlmodelc/.mlpackage
    if let enumerator = fm.enumerator(at: folder, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles], errorHandler: nil) {
      for case let fileURL as URL in enumerator {
        let lname = fileURL.lastPathComponent.lowercased()
        if searchNames.contains(lname) {
          if lname.hasSuffix(".txt") {
            if let s = try? String(contentsOf: fileURL, encoding: .utf8) {
              let lines = s.split(whereSeparator: { $0.isNewline }).map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
              if !lines.isEmpty { return lines }
            }
          } else if lname.hasSuffix(".json") {
            if let data = try? Data(contentsOf: fileURL), let arr = try? JSONSerialization.jsonObject(with: data) as? [String] {
              if !arr.isEmpty { return arr }
            }
          }
        }
      }
    }

    return nil
  }

  // Try to extract class labels from an MLModel using several fallbacks:
  // 1) known metadata keys that may contain [String]
  // 2) attempt to read any metadata value that looks like JSON and parse it
  // 3) Objective-C KVC fallback to read `classLabels` from the modelDescription (some models embed labels there)
  private func extractLabelsFromModel(_ mlModel: MLModel) -> [String]? {
    // 1) metadata keys
    let md = mlModel.modelDescription.metadata
    for (rawKey, value) in md {
      // metadata dictionary keys are MLModelMetadataKey; use the concrete rawValue
      let keyName = rawKey.rawValue.lowercased()

      if keyName.contains("class") || keyName.contains("label") || keyName.contains("classes") {
        if let arr = value as? [String], !arr.isEmpty { return arr }
        if let s = value as? String {
          // try parse JSON array in a string
          if let data = s.data(using: .utf8), let arr = try? JSONSerialization.jsonObject(with: data) as? [String], !arr.isEmpty {
            return arr
          }
        }
      }
    }

    // 2) Try to access modelDescription.classLabels via KVC (some Core ML descriptions expose this)
    // Use AnyObject to avoid compile-time coupling to private APIs; this is a safe read-only attempt.
    let desc = mlModel.modelDescription
    let anyDesc = desc as AnyObject
    // read the KVC result into a non-optional Any, then attempt casts/parsing
    let clAny: Any = anyDesc.value(forKey: "classLabels") as Any
    if let arr = clAny as? [String], !arr.isEmpty { return arr }
    // sometimes it's an MLFeatureValue-like wrapper or other container
    if let fv = clAny as? MLFeatureValue, fv.type == .string { return [fv.stringValue] }
    // try string representation that contains JSON
    let sdesc = String(describing: clAny)
    if let data = sdesc.data(using: .utf8), let arr = try? JSONSerialization.jsonObject(with: data) as? [String], !arr.isEmpty {
      return arr
    }

    return nil
  }

  // Load a VNCoreMLModel dynamically by searching compiled or raw model files in the bundle.
  // Returns the VN model, the underlying MLModel and any discovered labels.
  func loadVNModel(named key: String) -> (vnModel: VNCoreMLModel, mlModel: MLModel, labels: [String]?)? {
    let lowered = key.lowercased()
    let bundle = Bundle.main

    // Search for compiled models
    if let compiled = bundle.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil) {
      if let match = compiled.first(where: { $0.lastPathComponent.lowercased().contains(lowered) }) {
        do {
          let core = try MLModel(contentsOf: match)
          let v = try VNCoreMLModel(for: core)
          let labels = loadLabelsNear(match)
          return (v, core, labels)
        } catch {
          print("Failed to load compiled model at \(match): \(error)")
        }
      }
    }

    return nil
  }

  // Process a VN request's results and return classification results.
  func processVNRequest(_ request: VNRequest, _ error: Error?, mlModel: MLModel, modelLabels: [String]?) -> [ClassificationResult] {
    var resultsArray: [ClassificationResult] = []
    if let error = error {
      print(error.localizedDescription)
      return []
    }

    guard let rawResults = request.results, !rawResults.isEmpty else {
      print("No results returned from VN request.")
      return []
    }

    for anyObs in rawResults {
      if let cls = anyObs as? VNClassificationObservation {
        // If the model provided a numeric identifier (e.g. "738") try to map it to a label
        var labelText = cls.identifier
        if let labels = modelLabels {
          // identifier may be a number string representing the class index
          if let idx = Int(cls.identifier), idx >= 0, idx < labels.count {
            labelText = labels[idx]
          }
        }

        resultsArray.append(ClassificationResult(label: labelText, confidence: cls.confidence))

      } else if let fv = anyObs as? VNCoreMLFeatureValueObservation {
        // MLMultiArray output
        if fv.featureValue.type == .multiArray, let multi = fv.featureValue.multiArrayValue {
          let count = multi.count
          var scores = [Double](repeating: 0.0, count: count)

          switch multi.dataType {
          case .double:
            let ptr = multi.dataPointer.bindMemory(to: Double.self, capacity: count)
            let buffer = UnsafeBufferPointer(start: ptr, count: count)
            scores = Array(buffer)
          case .float32:
            let ptr = multi.dataPointer.bindMemory(to: Float.self, capacity: count)
            let buffer = UnsafeBufferPointer(start: ptr, count: count)
            scores = buffer.map { Double($0) }
          case .int32:
            let ptr = multi.dataPointer.bindMemory(to: Int32.self, capacity: count)
            let buffer = UnsafeBufferPointer(start: ptr, count: count)
            scores = buffer.map { Double($0) }
          default:
            for i in 0..<count {
              let idx = [NSNumber(value: i)]
              let val = multi[idx]
              scores[i] = val.doubleValue
            }
          }

          // Softmax
          let maxScore = scores.max() ?? 0.0
          let exps = scores.map { exp($0 - maxScore) }
          let sumExps = exps.reduce(0.0, +)
          let probs = exps.map { $0 / (sumExps == 0 ? 1 : sumExps) }

          // Top-K
          let topK = min(5, probs.count)
          let indexed = probs.enumerated().map { ($0.offset, $0.element) }
          let sorted = indexed.sorted(by: { $0.1 > $1.1 }).prefix(topK)

          // Labels: prefer explicit file labels, then metadata
          var labelsByIndex: [String]? = modelLabels
          if labelsByIndex == nil {
            let key = MLModelMetadataKey(rawValue: "com.apple.coreml.model-class-labels")
            if let metadata = mlModel.modelDescription.metadata[key] as? [String] {
              labelsByIndex = metadata
            }
          }

          for (idx, prob) in sorted {
            let labelText: String
            if let labels = labelsByIndex, idx < labels.count {
              labelText = labels[idx]
            } else {
              labelText = "Class \(idx)"
            }
            resultsArray.append(ClassificationResult(label: labelText, confidence: Float(prob)))
          }

        // Dictionary output
        } else if fv.featureValue.type == .dictionary {
          var labelProbs: [(String, Double)] = []
          if let dict = fv.featureValue.dictionaryValue as? [String: Any] {
            for (k, v) in dict {
              if let num = v as? NSNumber { labelProbs.append((k, num.doubleValue)) }
              else if let d = v as? Double { labelProbs.append((k, d)) }
              else if let f = v as? Float { labelProbs.append((k, Double(f))) }
              else if let i = v as? Int { labelProbs.append((k, Double(i))) }
            }
          }

          if !labelProbs.isEmpty {
            let values = labelProbs.map { $0.1 }
            let maxVal = values.max() ?? 0.0
            let exps = values.map { exp($0 - maxVal) }
            let sumExps = exps.reduce(0.0, +)
            let probs: [Double] = (sumExps > 0) ? exps.map { $0 / sumExps } : values

            let paired = zip(labelProbs.map { $0.0 }, probs).sorted(by: { $0.1 > $1.1 }).prefix(5)
            for (label, prob) in paired { resultsArray.append(ClassificationResult(label: label, confidence: Float(prob))) }
          }

        } else {
          print("VNCoreMLFeatureValueObservation contained unsupported featureValue.type: \(fv.featureValue.type)")
        }

      } else {
        print("Unhandled VNObservation type: \(type(of: anyObs))")
      }
    }

    // Ensure we return at most 6 predictions, sorted by confidence (highest first).
    let top = resultsArray.sorted(by: { $0.confidence > $1.confidence }).prefix(6)
    return Array(top)
  }

  func runModel() {
    guard let cgImage = cgImage else {
      print("No CGImage available to run model")
      DispatchQueue.main.async { self.isClassifying = false }
      return
    }

    guard let (vnModel, mlCoreModel, modelLabels) = loadVNModel(named: selectedModelKey.rawValue) else {
      print("Unable to load selected model: \(selectedModelKey.rawValue). Make sure the model is added to the target and compiled.")
      DispatchQueue.main.async { self.isClassifying = false }
      return
    }

    // If we didn't find labels by scanning files, try to extract them directly from the loaded MLModel metadata
    var effectiveLabels = modelLabels
    if effectiveLabels == nil {
      effectiveLabels = extractLabelsFromModel(mlCoreModel)
    }

    if effectiveLabels == nil {
      // helpful debug logging when labels aren't found so you can inspect the model's metadata
      print("No class labels found for model \(selectedModelKey.rawValue). Inspecting metadata keys:")
      for (k, v) in mlCoreModel.modelDescription.metadata {
        print("  key=\(k.rawValue) type=\(type(of: v)) value=\(v)")
      }
    } else {
      // Log discovered labels (count + first few) to help debugging
      let count = effectiveLabels!.count
      let sample = effectiveLabels!.prefix(5).joined(separator: ", ")
      print("Found \(count) class labels for model \(selectedModelKey.rawValue): [\(sample)\(count>5 ? ", ..." : "")]")
    }

    let request = VNCoreMLRequest(model: vnModel) { request, error in
      let resultsArray = self.processVNRequest(request, error, mlModel: mlCoreModel, modelLabels: effectiveLabels)
      DispatchQueue.main.async {
        self.classResults = resultsArray
        self.isClassifying = false
      }
    }

    request.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop

    let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
    do {
      try handler.perform([request])
    } catch {
      print("Failed to perform request: \(error)")
      DispatchQueue.main.async { self.isClassifying = false }
    }
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("Select Model:")
      Picker("Model", selection: $selectedModelKey) {
        ForEach(ModelType.allCases) { model in
          Text(model.display).tag(model)
        }
      }
      .pickerStyle(.segmented)
      .padding(.bottom, 8)

      PhotosPicker("Select Photo", selection: $selectedImage, matching: .images)
        .onChange(of: selectedImage) {
          Task {
            if let loadedImageData = try? await selectedImage?.loadTransferable(type: Data.self), let uiImage = UIImage(data: loadedImageData) {
              image = Image(uiImage: uiImage)
              cgImage = uiImage.cgImage
            }
          }
        }

      HStack {
        Button(action: {
          guard cgImage != nil, !isClassifying else { return }
          classResults = []
          isClassifying = true
          DispatchQueue.global(qos: .userInitiated).async { runModel() }
        }) {
          HStack {
            if isClassifying {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .padding(.trailing, 4)
            }
            Text(isClassifying ? "Classifying..." : "Classify")
          }
        }
        .disabled(cgImage == nil || isClassifying)
        Spacer()
      }
      .padding(.vertical, 8)

      // Make the image + results scrollable together
      ScrollView(.vertical) {
        VStack(alignment: .leading, spacing: 12) {
          if let image = image {
            ImageDisplayView(image: image)
              .padding(.bottom, 8)
          } else {
            NoImageSelectedView()
          }

          if classResults.isEmpty {
            Text("No results yet").foregroundColor(.secondary)
          } else {
            Text("Top results:")
            ForEach(classResults) { r in
              HStack {
                Text(r.label)
                Spacer()
                Text(r.confidence, format: .percent)
              }
              .padding(.vertical, 4)
            }
          }
        }
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
      }

    }
    .padding()
  }
}

#Preview {
  ContentView()
}
