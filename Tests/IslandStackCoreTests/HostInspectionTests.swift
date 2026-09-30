import Foundation
import XCTest
@testable import IslandStackCore

final class HostInspectionTests: XCTestCase {
  func testStopReportsInspectionFailureAndStillStopsOtherHelper() throws {
    let fixture = try SimulatorFixture(failedInspection: .a)
    defer { fixture.remove() }
    let host = try IslandStackHost(root: fixture.root, udid: "SIMULATOR", process: fixture.process)

    XCTAssertThrowsError(try host.stop(returnTo: fixture.target)) { error in
      guard case HostError.partialStop(let message) = error else {
        return XCTFail("Expected a partial cleanup failure, received \(error)")
      }
      XCTAssertTrue(message.contains("A:"))
      XCTAssertTrue(message.contains("Timed out"))
      XCTAssertTrue(message.contains("Stopped: B."))
    }
    XCTAssertEqual(fixture.activeHelpers, [.a])
    XCTAssertEqual(fixture.foregroundApp, fixture.target)
  }

  func testStatusPreservesInspectionFailureAndReturnsToTarget() throws {
    let fixture = try SimulatorFixture(failedInspection: .a)
    defer { fixture.remove() }
    let host = try IslandStackHost(root: fixture.root, udid: "SIMULATOR", process: fixture.process)

    XCTAssertThrowsError(try host.status(returnTo: fixture.target)) { error in
      guard case SystemProcessError.timedOut = error else {
        return XCTFail("Expected the Simulator query failure, received \(error)")
      }
    }
    XCTAssertEqual(fixture.activeHelpers, [.a, .b])
    XCTAssertEqual(fixture.foregroundApp, fixture.target)
  }
}

private final class SimulatorFixture {
  let root: URL
  let target = "dev.test.target"
  let failedInspection: Competitor
  var activeHelpers: Set<Competitor> = [.a, .b]
  var foregroundApp: String?
  private var inspectionCount = 0

  init(failedInspection: Competitor) throws {
    self.failedInspection = failedInspection
    root = FileManager.default.temporaryDirectory
      .appendingPathComponent("islandstack-inspection-tests-\(UUID().uuidString)")
    for path in ["ios/Competitor.xcodeproj", "ios/ShortcutDriver.xcodeproj", "B/Documents"] {
      try FileManager.default.createDirectory(
        at: root.appendingPathComponent(path), withIntermediateDirectories: true
      )
    }
  }

  func remove() {
    try? FileManager.default.removeItem(at: root)
  }

  var process: ProcessRunner {
    ProcessRunner { [self] executable, arguments, _ in
      if arguments == ["-version"] { return "Xcode test fixture" }
      if arguments.starts(with: ["simctl", "listapps"]) {
        inspectionCount += 1
        let failedProbe = failedInspection == .a ? 2 : 3
        if inspectionCount == failedProbe { throw inspectionError }
        let apps = [target: [:], Competitor.a.bundleID: [:], Competitor.b.bundleID: [:]]
        let data = try PropertyListSerialization.data(fromPropertyList: apps, format: .xml, options: 0)
        return String(decoding: data, as: UTF8.self)
      }
      if arguments.starts(with: ["simctl", "get_app_container"]) {
        return root.appendingPathComponent("B").path
      }
      if arguments.contains("-only-testing:ShortcutDriverUITests/ShortcutActionsUITests/testStopB") {
        activeHelpers.remove(.b)
        let receipt: [String: Any] = [
          "requestID": UUID().uuidString, "command": "stop", "identity": Competitor.b.bundleID,
          "source": "intent", "count": 0, "activityIDs": [], "observedAt": "2026-09-30T12:00:00Z"
        ]
        try JSONSerialization.data(withJSONObject: receipt)
          .write(to: root.appendingPathComponent("B/Documents/intent-last.json"))
        return "Test succeeded"
      }
      if arguments.starts(with: ["simctl", "launch"]) {
        foregroundApp = arguments.last
        return "Launched"
      }
      XCTFail("Unexpected external command: \(executable) \(arguments)")
      throw inspectionError
    }
  }

  private var inspectionError: SystemProcessError {
    .timedOut(command: "Simulator installation query", seconds: 20)
  }
}
