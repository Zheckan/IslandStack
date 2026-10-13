import SwiftUI

@main
struct CompetitorApp: App {
  @Environment(\.scenePhase) private var scenePhase
  @State private var isActive = false
  @State private var isWorking = false
  @State private var errorMessage: String?

  var body: some Scene {
    WindowGroup {
      Button {
        Task { await toggleActivity() }
      } label: {
        VStack(spacing: 24) {
          Image(systemName: isActive ? "stop.circle.fill" : CompetitorStyle.symbol)
            .font(.system(size: 88, weight: .medium))
          Text(isActive ? "Stop Live Activity" : "Activate Live Activity")
            .font(.largeTitle.weight(.semibold))
            .multilineTextAlignment(.center)
          Text(CompetitorStyle.name)
            .font(.headline)
            .foregroundStyle(.secondary)
        }
        .foregroundStyle(CompetitorStyle.color)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(isWorking)
      .accessibilityLabel(isActive ? "Stop Live Activity" : "Activate Live Activity")
      .accessibilityHint("Controls one Live Activity for \(CompetitorStyle.name)")
      .alert("Could not update Live Activity", isPresented: Binding(
        get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
      )) {
        Button("OK", role: .cancel) { errorMessage = nil }
      } message: {
        Text(errorMessage ?? "")
      }
      .task {
        await handleLaunchCommand()
        await refreshActivity()
      }
      .onChange(of: scenePhase) { _, phase in
        if phase == .active { Task { await refreshActivity() } }
      }
    }
  }

  @MainActor private func toggleActivity() async {
    guard !isWorking else { return }
    isWorking = true
    defer { isWorking = false }
    let receipt = await ActivityController.run(
      command: isActive ? "stop" : "start", requestID: UUID().uuidString, source: "app"
    )
    isActive = receipt.count > 0
    errorMessage = receipt.error
  }

  @MainActor private func refreshActivity() async {
    let receipt = await ActivityController.run(command: "status", requestID: UUID().uuidString, source: "app")
    isActive = receipt.count > 0
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
