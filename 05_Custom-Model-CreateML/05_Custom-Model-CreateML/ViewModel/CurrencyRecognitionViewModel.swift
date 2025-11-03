//
//  CurrencyRecognitionViewModel.swift
//  05_Custom-Model-CreateML
//
//  Created by Ashok Vardhan Jangeti on 03/11/25.
//


import SwiftUI
import Combine
import CoreML

class CurrencyRecognitionViewModel: ObservableObject {
  @Published var image: UIImage?
  @Published var currencyLabel: String?
  @Published var accuracy: String?

  @Published var topResults: [(label: String, confidence: Float)] = []
  @Published var isLoading: Bool = false
  @Published var useTTA: Bool = false
  @Published var topK: Int = 4
  @Published var confidenceThreshold: Float = 0.0
  @Published var computeUnits: MLComputeUnits = .cpuOnly

  private var recognizer: CurrencyRecognitionService?

  init() {
    do {
      self.recognizer = try CurrencyRecognitionService(preferredComputeUnits: computeUnits)
    } catch {
      print("Failed to init CurrencyRecognitionService: \(error.localizedDescription)")
      self.recognizer = nil
    }
  }

  func classifyImage() {
    guard let img = self.image else { return }
    isLoading = true
    currencyLabel = nil
    accuracy = nil
    topResults = []

    if recognizer == nil {
      do {
        recognizer = try CurrencyRecognitionService(preferredComputeUnits: computeUnits)
      } catch {
        DispatchQueue.main.async {
          self.isLoading = false
          self.currencyLabel = "Model load error"
          self.accuracy = nil
        }
        return
      }
    }

    if useTTA {
      recognizer?.classifyWithTTA(image: img, topK: topK, confidenceThreshold: confidenceThreshold) { [weak self] results, error in
        DispatchQueue.main.async {
          self?.isLoading = false
          if let results = results, !results.isEmpty {
            self?.topResults = results
            let first = results.first!
            self?.currencyLabel = first.label
            self?.accuracy = String(format: "%.2f%%", first.confidence * 100)
          } else {
            self?.currencyLabel = nil
            self?.accuracy = nil
            self?.topResults = []
          }
        }
      }
    } else {
      recognizer?.classifyTopK(image: img, topK: topK, confidenceThreshold: confidenceThreshold) { [weak self] results, error in
        DispatchQueue.main.async {
          self?.isLoading = false
          if let results = results, !results.isEmpty {
            self?.topResults = results
            let first = results.first!
            self?.currencyLabel = first.label
            self?.accuracy = String(format: "%.2f%%", first.confidence * 100)
          } else {
            self?.currencyLabel = nil
            self?.accuracy = nil
            self?.topResults = []
          }
        }
      }
    }
  }

  func reset() {
    DispatchQueue.main.async {
      self.image = nil
      self.currencyLabel = nil
      self.accuracy = nil
      self.topResults = []
      self.isLoading = false
    }
  }

  func updateComputeUnits(_ units: MLComputeUnits) {
    computeUnits = units
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self = self else { return }
      do {
        if self.recognizer == nil {
          self.recognizer = try CurrencyRecognitionService(preferredComputeUnits: units)
        } else {
          try self.recognizer?.setComputeUnits(units)
        }
      } catch {
        print("Failed to update compute units: \(error.localizedDescription)")
      }
    }
  }
}
