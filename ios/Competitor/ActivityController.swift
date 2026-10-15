import ActivityKit
import Foundation

struct CommandReceipt: Encodable {
  let requestID: String
  let command: String
  let identity: String
  let source: String
  let observedAt: Date
  let activityIDs: [String]
  let error: String?

  var count: Int { activityIDs.count }

  enum CodingKeys: String, CodingKey {
    case requestID, command, identity, source, observedAt, activityIDs, error, count
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(requestID, forKey: .requestID)
    try container.encode(command, forKey: .command)
    try container.encode(identity, forKey: .identity)
    try container.encode(source, forKey: .source)
    try container.encode(observedAt, forKey: .observedAt)
    try container.encode(activityIDs, forKey: .activityIDs)
    try container.encode(count, forKey: .count)
    try container.encode(error, forKey: .error)
  }
}

@MainActor
enum ActivityController {
  static func run(command: String, requestID: String, source: String) async -> CommandReceipt {
    var errorMessage: String?

    do {
      for activity in Activity<CompetitorAttributes>.activities
      where activity.content.state.endsAt <= Date() {
        await activity.end(nil, dismissalPolicy: .immediate)
      }

      switch command {
      case "start":
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
          throw CommandError.activitiesDisabled
        }
        let existing = Activity<CompetitorAttributes>.activities
        if existing.isEmpty {
          let endsAt = Date().addingTimeInterval(20 * 60)
          let content = ActivityContent(
            state: CompetitorAttributes.ContentState(endsAt: endsAt),
            staleDate: endsAt
          )
          _ = try Activity<CompetitorAttributes>.request(
            attributes: CompetitorAttributes(title: CompetitorStyle.name),
            content: content,
            pushType: nil
          )
        } else {
          for activity in existing.dropFirst() {
            await activity.end(nil, dismissalPolicy: .immediate)
          }
        }
      case "status":
        break
      case "stop":
        for activity in Activity<CompetitorAttributes>.activities {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
      default:
        throw CommandError.unknownCommand(command)
      }
    } catch {
      errorMessage = error.localizedDescription
    }

    return CommandReceipt(
      requestID: requestID,
      command: command,
      identity: Bundle.main.bundleIdentifier ?? "unknown",
      source: source,
      observedAt: Date(),
      activityIDs: Activity<CompetitorAttributes>.activities.map(\.id).sorted(),
      error: errorMessage
    )
  }

  nonisolated static func write(_ receipt: CommandReceipt, filename: String) throws {
    let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(receipt)
    try data.write(to: documents.appendingPathComponent(filename), options: .atomic)
  }
}

private enum CommandError: LocalizedError {
  case activitiesDisabled
  case unknownCommand(String)

  var errorDescription: String? {
    switch self {
    case .activitiesDisabled:
      "Live Activities are disabled on this simulator."
    case .unknownCommand(let command):
      "Unknown command: \(command)"
    }
  }
}
