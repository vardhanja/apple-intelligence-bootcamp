// AnnounceSessionIntent.swift
// Adds a Siri-capable intent that speaks session information when a screen isn't available.

import Foundation
import AppIntents

struct AnnounceSessionIntent: AppIntent {
  static var title: LocalizedStringResource = "Announce Session"
  static var description = IntentDescription(
    "Announces key details about a session using Siri. Useful when no screen is available.",
    categoryName: "Siri")

  @Parameter(title: "Session", description: "The session to announce.")
  var session: SessionEntity

  @Dependency private var sessionManager: SessionDataManager

  // Provide a concise sentence for the Shortcuts editor that includes the session parameter.
  static var parameterSummary: some ParameterSummary {
    Summary("Announce details for \(\.$session)")
  }

  /// Return a dialog so Siri can speak the response when no UI is available.
  func perform() async throws -> some IntentResult & ProvidesDialog {
      guard let sessionData = await sessionManager.session(with: session.id) else {
      throw SessionIntentError.sessionNotFound
    }

    // Build voice-friendly short phrases. Keep them concise for Siri.
    // Provide a slightly longer supporting line explaining where to get more details.
    let name = sessionData.name
    // Ensure description isn't too long for a voice announcement; truncate if needed.
    let descriptionText = sessionData.sessionDescription
    let truncatedDescription: String
    if descriptionText.count > 140 {
      let idx = descriptionText.index(descriptionText.startIndex, offsetBy: 137)
      truncatedDescription = String(descriptionText[..<idx]) + "..."
    } else {
      truncatedDescription = descriptionText
    }

    let length = sessionData.sessionLength

    // Use LocalizedStringResource so IntentDialog accepts the strings.
    let full = LocalizedStringResource("\(name). \(truncatedDescription)")
    let supporting = LocalizedStringResource("Session length: \(length). Say 'Open session' to view more in the app.")
    let dialog = IntentDialog(full: full, supporting: supporting)

    return .result(dialog: dialog)
  }
}
