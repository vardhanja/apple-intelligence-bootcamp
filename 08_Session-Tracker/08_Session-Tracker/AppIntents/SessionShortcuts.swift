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

import Foundation
import AppIntents

final class SessionShortcuts: AppShortcutsProvider {
  static var shortcutTileColor = ShortcutTileColor.navy

  static var appShortcuts: [AppShortcut] {
    // Get Details
    AppShortcut(
      intent: GetSessionDetails(),
      phrases: ["Get details in \(.applicationName)"],
      shortTitle: "Get Details",
      systemImageName: "cloud.rainbow.half"
    )

    // Announce
    AppShortcut(
      intent: AnnounceSessionIntent(),
      phrases: ["Announce in \(.applicationName)"],
      shortTitle: "Announce",
      systemImageName: "megaphone.fill"
    )

    // Add Favorite
    AppShortcut(
      intent: AddFavoriteSessionIntent(),
      phrases: [
        "Add to favorites in \(.applicationName)",
        "Add \(\.$sessionToAdd) to favorites in \(.applicationName)",
        "Add \(\.$sessionToAdd) to my favorites in \(.applicationName)",
        "Add favorite \(\.$sessionToAdd) in \(.applicationName)"
      ],
      shortTitle: "Add Favorite",
      systemImageName: "heart.fill",
      parameterPresentation: ParameterPresentation(
        for: \.$sessionToAdd,
        summary: Summary("Add \(\.$sessionToAdd) to Favorites")) {
          OptionsCollection(SessionEntityQuery(), title: "Favorite Sessions", systemImageName: "heart.fill")
      }
    )

    // Open in browser
    AppShortcut(
      intent: OpenURLInTabIntent(),
      phrases: [
        "Open \(\.$session) details with \(.applicationName) in a browser",
        "Get details for \(\.$session) with \(.applicationName) in a browser"
      ],
      shortTitle: "Open in browser",
      systemImageName: "cloud.rainbow.half"
    )

    // Open Favorites
    AppShortcut(
      intent: OpenFavorites(),
      phrases: ["Open Favorites in \(.applicationName)", "Show my favorite \(.applicationName)"],
      shortTitle: "Open Favorites",
      systemImageName: "star.circle"
    )
  }
}
