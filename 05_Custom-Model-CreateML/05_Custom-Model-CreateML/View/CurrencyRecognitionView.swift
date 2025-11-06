//
//  CurrencyRecognitionView.swift
//  05_Custom-Model-CreateML
//
//  Created by Ashok Vardhan Jangeti on 03/11/25.
//


import SwiftUI

struct CurrencyRecognitionView: View {
    @StateObject private var viewModel = CurrencyRecognitionViewModel()
    @State private var isShowingImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showSourceTypeActionSheet = false

    var body: some View {
      VStack(spacing: 20) {
        ImageDisplayView(image: $viewModel.image, showSourceTypeActionSheet: $showSourceTypeActionSheet)
        
        if viewModel.isLoading {
          ProgressView("Analyzing...")
            .padding()
        }
        
        // Results area: top-K list if available
        if !viewModel.topResults.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Top Results")
              .font(.headline)
            ForEach(Array(viewModel.topResults.enumerated()), id: \.offset) { idx, result in
              HStack {
                Text("\(idx + 1). \(result.label)")
                Spacer()
                Text(String(format: "%.2f%%", result.confidence * 100))
                  .foregroundColor(.secondary)
              }
              .padding(.vertical, 4)
            }
          }
          .padding()
          .background(Color.green.opacity(0.06))
          .cornerRadius(8)
        } else if let label = viewModel.currencyLabel {
          CurrencyResultView(currency: label, accuracy: viewModel.accuracy ?? "")
        }
        
        // Action buttons (use defaults)
        ActionButtonsView(
          image: $viewModel.image,
          classifyImage: viewModel.classifyImage,
          reset: viewModel.reset,
          detectTitle: "Detect Currency"
        )
      }
        
        .navigationTitle("Currency Recognition")
        .actionSheet(isPresented: $showSourceTypeActionSheet) {
            ActionSheet(title: Text("Select Image Source"), message: nil, buttons: [
                .default(Text("Camera")) {
                    self.sourceType = .camera
                    self.isShowingImagePicker = true
                },
                .default(Text("Photo Library")) {
                    self.sourceType = .photoLibrary
                    self.isShowingImagePicker = true
                },
                .cancel()
            ])
        }
        .sheet(isPresented: $isShowingImagePicker) {
            ImagePicker(image: self.$viewModel.image, sourceType: self.$sourceType)
        }
    }
}

#Preview {
    CurrencyRecognitionView()
}