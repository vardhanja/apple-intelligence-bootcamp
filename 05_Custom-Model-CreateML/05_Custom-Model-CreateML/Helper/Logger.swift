// Simple debug logger used across the app.
// In release builds this compiles to an empty function so there's no runtime overhead.

import Foundation

@inline(__always) func appLog(_ message: @autoclosure () -> String) {
  #if DEBUG
  print(message())
  #else
  // no-op in release
  #endif
}
