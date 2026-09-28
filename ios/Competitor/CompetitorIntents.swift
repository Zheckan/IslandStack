import AppIntents
import Foundation

@available(iOS 17.0, *)
struct StartCompetitorIntent: LiveActivityIntent {
  #if COMPETITOR_B
  static let title: LocalizedStringResource = "Start IslandStack B"
  #else
  static let title: LocalizedStringResource = "Start IslandStack A"
  #endif
  static var openAppWhenRun: Bool { false }

  func perform() async throws -> some IntentResult {
    let receipt = await ActivityController.run(
      command: "start", requestID: UUID().uuidString, source: "intent"
    )
    try ActivityController.write(receipt, filename: "intent-last.json")
    if let error = receipt.error { throw IntentFailure.message(error) }
    return .result()
  }
}

@available(iOS 17.0, *)
struct StopCompetitorIntent: LiveActivityIntent {
  #if COMPETITOR_B
  static let title: LocalizedStringResource = "Stop IslandStack B"
  #else
  static let title: LocalizedStringResource = "Stop IslandStack A"
  #endif
  static var openAppWhenRun: Bool { false }

  func perform() async throws -> some IntentResult {
    let receipt = await ActivityController.run(
      command: "stop", requestID: UUID().uuidString, source: "intent"
    )
    try ActivityController.write(receipt, filename: "intent-last.json")
    if let error = receipt.error { throw IntentFailure.message(error) }
    return .result()
  }
}

@available(iOS 17.0, *)
struct StatusCompetitorIntent: AppIntent {
  #if COMPETITOR_B
  static let title: LocalizedStringResource = "Status IslandStack B"
  #else
  static let title: LocalizedStringResource = "Status IslandStack A"
  #endif
  static var openAppWhenRun: Bool { false }

  func perform() async throws -> some IntentResult {
    let receipt = await ActivityController.run(
      command: "status", requestID: UUID().uuidString, source: "intent"
    )
    try ActivityController.write(receipt, filename: "intent-last.json")
    if let error = receipt.error { throw IntentFailure.message(error) }
    return .result()
  }
}

@available(iOS 17.0, *)
struct CompetitorShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    #if COMPETITOR_B
    AppShortcut(intent: StartCompetitorIntent(), phrases: ["Start B in \(.applicationName)"], shortTitle: "Start B", systemImageName: "flame.fill")
    AppShortcut(intent: StopCompetitorIntent(), phrases: ["Stop B in \(.applicationName)"], shortTitle: "Stop B", systemImageName: "stop.circle")
    AppShortcut(intent: StatusCompetitorIntent(), phrases: ["Status B in \(.applicationName)"], shortTitle: "Status B", systemImageName: "info.circle")
    #else
    AppShortcut(intent: StartCompetitorIntent(), phrases: ["Start A in \(.applicationName)"], shortTitle: "Start A", systemImageName: "bolt.fill")
    AppShortcut(intent: StopCompetitorIntent(), phrases: ["Stop A in \(.applicationName)"], shortTitle: "Stop A", systemImageName: "stop.circle")
    AppShortcut(intent: StatusCompetitorIntent(), phrases: ["Status A in \(.applicationName)"], shortTitle: "Status A", systemImageName: "info.circle")
    #endif
  }
}

private enum IntentFailure: Error {
  case message(String)
}
