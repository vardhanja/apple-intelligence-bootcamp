import Foundation
import SwiftUI
import Combine

// MARK: - SessionCollection

final class SessionCollection: Identifiable, @unchecked Sendable {
  enum CollectionType: Int, Hashable, Codable, Sendable {
    case favorites = 0
    case browseSessions = 1
    case featured = 2
  }

  /// The collection's stable identifier.
  let id: Int

  /// What the collection represents, for UI purposes.
  let collectionType: CollectionType

  /// The name of the collection to display in the UI.
  var displayName: String

  /// A symbol to use with the collection in the UI.
  let symbolName: String

  /// The session IDs that belong to this collection.
  var members: [Session.ID]

  init(id: Int, collectionType: CollectionType, displayName: String, symbolName: String, members: [Session.ID]) {
    self.id = id
    self.collectionType = collectionType
    self.symbolName = symbolName
    self.members = members
    self.displayName = displayName
  }

  // MARK: - Decodable support
  private enum CodingKeys: CodingKey {
    case id
    case collectionType
    case displayName
    case symbolName
    case members
  }

  convenience init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let id = try values.decode(Int.self, forKey: .id)
    let collectionType = try values.decode(CollectionType.self, forKey: .collectionType)
    let symbolName = try values.decode(String.self, forKey: .symbolName)
    let members = try values.decode([Int].self, forKey: .members)
    let displayName = try values.decode(String.self, forKey: .displayName)
    self.init(id: id, collectionType: collectionType, displayName: displayName, symbolName: symbolName, members: members)
  }
}

extension SessionCollection: Decodable {}

extension SessionCollection: Hashable {
  static func == (lhs: SessionCollection, rhs: SessionCollection) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
