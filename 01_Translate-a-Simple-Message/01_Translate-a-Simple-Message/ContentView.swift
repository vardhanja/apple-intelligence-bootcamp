//
//  ContentView.swift
//  01_Translate-a-Simple-Message
//
//  Created by Ashok Vardhan Jangeti on 16/10/25.
//

import SwiftUI
import Translation

struct ContentView: View {
    @State private var showTranslation = false
    @State private var inputText: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Enter text", text: $inputText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
            Button("Translate") {
                showTranslation.toggle()
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.isEmpty)
        }
        .padding()
        .translationPresentation(isPresented: $showTranslation, text: inputText) {
            translatedText in
            inputText = translatedText
        }
        
        
    }
}

#Preview {
    ContentView()
}
