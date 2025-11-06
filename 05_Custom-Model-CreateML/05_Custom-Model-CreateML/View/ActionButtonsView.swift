//
//  ActionButtonsView.swift
//  05_Custom-Model-CreateML
//
//  Created by Ashok Vardhan Jangeti on 03/11/25.
//


import SwiftUI

struct ActionButtonsView: View {
  @Binding var image: UIImage?
  var classifyImage: () -> Void
  var reset: () -> Void
  var detectTitle: String = "Detect Disease"
  var resetTitle: String = "Upload Another Image"

  var body: some View {
    VStack(spacing: 10) {
      if image != nil {
        Button(action: classifyImage) {
          Text(detectTitle)
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal)

        Button(action: reset) {
          Text(resetTitle)
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding(.horizontal)
      }
    }
  }
}

#Preview {
  ActionButtonsView(
    image: .constant(UIImage(systemName: "photo")),
    classifyImage: {},
    reset: {}
  )
}