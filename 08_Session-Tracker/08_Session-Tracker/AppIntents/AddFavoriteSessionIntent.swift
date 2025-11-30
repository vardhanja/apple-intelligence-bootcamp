import Foundation
import AppIntents

struct AddFavoriteSessionIntent: AppIntent {
  static var title: LocalizedStringResource = "Add to Favorites"
  static var description = IntentDescription("Adds a session to your favorites.")

  static var parameterSummary: some ParameterSummary {
    Summary("Add \(\.$sessionToAdd) to Favorites")
  }

  @Parameter(title: "Session", description: "The session to add to favorites.")
  var sessionToAdd: SessionEntity

  @Dependency private var sessionManager: SessionDataManager

  func perform() async throws -> some IntentResult & ReturnsValue<SessionEntity> & ProvidesDialog {
    guard let _ = sessionManager.session(with: sessionToAdd.id) else {
      throw SessionIntentError.sessionNotFound
    }

    let added = sessionManager.addToFavorites(sessionToAdd.id)
    let dialog: IntentDialog
    if added {
      dialog = IntentDialog(full: LocalizedStringResource("Added \(sessionToAdd.name) to your favorites."), supporting: "You can view your favorites in the Favorites section.")
    } else {
      dialog = IntentDialog(full: LocalizedStringResource("\(sessionToAdd.name) is already in your favorites."), supporting: "No action was taken.")
    }
    return .result(value: sessionToAdd, dialog: dialog)
  }
}
