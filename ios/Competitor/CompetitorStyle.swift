import SwiftUI

enum CompetitorStyle {
  #if COMPETITOR_C
  static let name = "IslandStack C"
  static let symbol = "moon.fill"
  static let color = Color.purple
  #elseif COMPETITOR_B
  static let name = "IslandStack B"
  static let symbol = "flame.fill"
  static let color = Color.orange
  #else
  static let name = "IslandStack A"
  static let symbol = "bolt.fill"
  static let color = Color.cyan
  #endif
}
