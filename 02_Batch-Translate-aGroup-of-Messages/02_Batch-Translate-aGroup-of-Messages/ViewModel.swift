//
//  ViewModel.swift
//  02_Batch-Translate-aGroup-of-Messages
//
//  Created by Ashok Vardhan Jangeti on 16/10/25.
//

import Translation
import Foundation
import NaturalLanguage

@Observable
class ViewModel {
    var isTranslationSupported: Bool?
    var tasks: [TaskItem] = []
    var availableLanguages: [AvailableLanguage] = []
    var translateFrom: Locale.Language?
    var translateTo: Locale.Language?
    
    init() {
        tasks = [
            TaskItem(title: "Buy milk and eggs"),
            TaskItem(title: "Walk the dog for 30 minutes"),
            TaskItem(title: "Finish the weekly report")
        ]
        prepareSupportedLanguages()
    }
    
    func reset() {
        isTranslationSupported = nil
    }
    
    func prepareSupportedLanguages() {
        Task { @MainActor in
            let supportedLanguages = await LanguageAvailability().supportedLanguages
            availableLanguages = supportedLanguages.map {
                AvailableLanguage(locale: $0)
            }.sorted()
        }
    }
}

// MARK: - Language availability

extension ViewModel {
    /// Detects the dominant language from the list of tasks.
    func detectSourceLanguage() {
        // Combine all task titles into a single string for analysis
        let allTaskText = tasks.map { $0.title }.joined(separator: " ")
        
        // Use NLLanguageRecognizer to find the dominant language
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(allTaskText)
        
        if let dominantLanguageCode = recognizer.dominantLanguage?.rawValue {
            // Set the detected language
            self.translateFrom = Locale.Language(identifier: dominantLanguageCode)
        } else {
            // **As requested, fallback to US English if detection fails**
            self.translateFrom = Locale.Language(identifier: "en-US")
        }
    }
    
    func checkLanguageSupport(from source: Locale.Language, to target: Locale.Language) async {
        translateFrom = source
        translateTo = target
        
        guard let translateFrom = translateFrom else { return }
        
        let status = await LanguageAvailability().status(from: translateFrom, to: translateTo)
        
        switch status {
        case .installed, .supported:
            isTranslationSupported = true
        case .unsupported:
            isTranslationSupported = false
        @unknown default:
            print("Translation support status for the selected language pair is unknown")
        }
    }
}

extension ViewModel {
    func translateSequence(using session: TranslationSession) async {
        let taskList = tasks.compactMap { $0.title }
        let requests: [TranslationSession.Request] = taskList.enumerated().map { (index, string) in
                .init(sourceText: string, clientIdentifier: "\(index)")
        }
        
        do {
            for try await response in session.translate(batch: requests) {
                guard let index = Int(response.clientIdentifier ?? "") else { continue }
                tasks[index].title = response.targetText
            }
        } catch {
            print("Error executing translateSequence: \(error)")
        }
    }
}

