//
//  PlantDiseaseDetectionView.swift
//  05_Custom-Model-CreateML
//
//  Created by Ashok Vardhan Jangeti on 03/11/25.
//


import SwiftUI

struct PlantDiseaseDetectionView: View {
    @StateObject private var viewModel = PlantDiseaseDetectionViewModel()
    @State private var isShowingImagePicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showSourceTypeActionSheet = false

    var body: some View {
        VStack(spacing: 20) {
            ImageDisplayView(image: $viewModel.image, showSourceTypeActionSheet: $showSourceTypeActionSheet)

            if let disease = viewModel.disease, let accuracy = viewModel.accuracy {
                PlantDiseaseResultView(disease: disease, accuracy: accuracy)
            }

            ActionButtonsView(image: $viewModel.image, classifyImage: viewModel.classifyImage, reset: viewModel.reset)
        }
        .navigationTitle("Plant Disease Detection")
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
    PlantDiseaseDetectionView()
}
