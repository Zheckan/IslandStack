import SwiftUI

@main
struct CompetitorApp: App {
  var body: some Scene {
    WindowGroup {
      VStack(spacing: 12) {
        Image(systemName: CompetitorStyle.symbol)
          .font(.largeTitle)
          .foregroundStyle(CompetitorStyle.color)
        Text(CompetitorStyle.name)
        Text("Controlled by IslandStack")
          .foregroundStyle(.secondary)
      }
      .task { await handleLaunchCommand() }
    }
  }

  private func handleLaunchCommand() async {
    let arguments = ProcessInfo.processInfo.arguments
    guard arguments.count == 3, UUID(uuidString: arguments[2]) != nil else { return }
    let requestID = arguments[2]
    let receipt = await ActivityController.run(
      command: arguments[1], requestID: requestID, source: "launch"
    )
    try? ActivityController.write(receipt, filename: "response-\(requestID).json")
  }
}
