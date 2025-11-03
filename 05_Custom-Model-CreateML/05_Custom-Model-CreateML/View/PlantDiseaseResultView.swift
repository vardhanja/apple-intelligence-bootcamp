//
//  PlantDiseaseResultView.swift
//  05_Custom-Model-CreateML
//
//  Created by Ashok Vardhan Jangeti on 03/11/25.
//


import SwiftUI

struct PlantDiseaseResultView: View {
  let disease: String
  let accuracy: String

  var body: some View {
    VStack(spacing: 5) {
      Text("Detected Disease: \(disease)")
        .font(.title2)
        .padding(.bottom)
      Text("Accuracy: \(accuracy)")
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
    .padding()
    .background(Color.green.opacity(0.1))
    .cornerRadius(10)
    .shadow(radius: 10)
  }
}

#Preview {
  PlantDiseaseResultView(disease: "Healthy", accuracy: "100%")
}
