/// Copyright (c) 2024 Kodeco Inc.
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import SwiftUI
import Translation

struct TranslationConfigView: View {
    // Use the shared ViewModel from the environment
    @Environment(ViewModel.self) var viewModel
    @Environment(\.dismiss) private var dismiss

    // Local state only for the user's selection
    @State private var selectedTo: Locale.Language?

    private var sourceLanguageName: String {
        guard let sourceLanguage = viewModel.translateFrom else {
            return "Detecting..."
        }
        if let identifier = sourceLanguage.languageCode?.identifier {
            return Locale.current.localizedString(forIdentifier: identifier) ?? "Unknown"
        } else {
            return "Unknown"
        }
    }

    // Closure to be called when translation is triggered
    let onTranslate: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("The source language is detected from your tasks. Select a target language to translate to.")
                .padding(.horizontal)
                .multilineTextAlignment(.center)

            List {
                // 1. SOURCE LANGUAGE: Displayed as static, non-editable text
                HStack {
                    Text("Source")
                    Spacer()
                    // Show the detected language name, or "Detecting..." initially
                    Text(sourceLanguageName)
                        .foregroundColor(.gray)
                }

                // 2. TARGET LANGUAGE: User can still pick this
                Picker("Target", selection: $selectedTo) {
                    // Add a placeholder option
                    Text("Select a Language").tag(Optional<Locale.Language>(nil))

                    ForEach(viewModel.availableLanguages) { language in
                        Text(language.localizedName())
                            .tag(Optional(language.locale))
                    }
                }

                // 3. SUPPORT STATUS: Shows if the selected pair is valid
                HStack {
                    Spacer()
                    if let isSupported = viewModel.isTranslationSupported {
                        VStack {
                            Text(isSupported ? "✅" : "❌")
                                .font(.largeTitle)
                            if !isSupported {
                                Text("Translation not supported.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else if selectedTo != nil {
                        // Show a progress view only if a target is selected but not yet checked
                        ProgressView()
                    }
                    Spacer()
                }
            }

            // Translate button
            Button("Translate") {
                onTranslate()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .onAppear {
            // 4. When the view appears, automatically detect the source language
            viewModel.detectSourceLanguage()
        }
        .onChange(of: selectedTo) {
            // 5. When the user picks a target, check for support
            Task {
                guard let targetLanguage = selectedTo else {
                    viewModel.isTranslationSupported = nil // Reset if user deselects
                    return
                }
                await viewModel.checkLanguageSupport(from: viewModel.translateFrom!, to: targetLanguage)
            }
        }
        .onDisappear() {
            viewModel.reset()
        }
        .padding()
        .navigationTitle("Translation Config").navigationBarTitleDisplayMode(.inline)
    }
}
