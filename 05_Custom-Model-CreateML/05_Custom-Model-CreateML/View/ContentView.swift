//
//  ContentView.swift
//  05_Custom-Model-CreateML
//
//  Created by Ashok Vardhan Jangeti on 03/11/25.
//
import SwiftUI

struct ContentView: View {
  var body: some View {
    NavigationView {
      VStack(spacing: 24) {
        Text("Welcome to AI Image Tools")
          .font(.title)
          .padding(.top)

        VStack(spacing: 30) {
          NavigationLink {
            PlantDiseaseDetectionView()
          } label: {
            Text("Start Plant Disease Detection")
              .font(.headline)
              .padding()
              .frame(maxWidth: .infinity)
              .background(Color.green)
              .foregroundColor(.white)
              .cornerRadius(10)
          }

          NavigationLink {
            CurrencyRecognitionView()
          } label: {
            Text("Start Currency Recognition")
              .font(.headline)
              .padding()
              .frame(maxWidth: .infinity)
              .background(Color.orange)
              .foregroundColor(.white)
              .cornerRadius(10)
          }
        }
        .padding(.horizontal)

        Spacer()
      }
      .padding()
      .navigationTitle("Custom Models")
    }

  }
}


struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
