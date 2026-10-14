import SwiftUI

enum CompetitorStyle {
  #if COMPETITOR_C
  static let name = "Drummond"
  static let symbol = "moon.fill"
  static let color = Color.purple
  #elseif COMPETITOR_B
  static let name = "Tordarroch"
  static let symbol = "flame.fill"
  static let color = Color.orange
  #else
  static let name = "An Craite"
  static let symbol = "bolt.fill"
  static let color = Color.cyan
  #endif
}
