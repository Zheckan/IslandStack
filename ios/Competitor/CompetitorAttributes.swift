import ActivityKit
import Foundation

struct CompetitorAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    let endsAt: Date
  }

  let title: String
}
