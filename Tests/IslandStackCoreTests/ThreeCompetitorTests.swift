import Foundation
import XCTest
@testable import IslandStackCore

final class ThreeCompetitorTests: XCTestCase {
  func testInstallThreeLeavesActivitiesStopped() throws {
    let fixture = try HelperFixture()
    defer { fixture.remove() }
    let host = try IslandStackHost(root: fixture.root, udid: "SIMULATOR", process: fixture.process)
    XCTAssertEqual(try host.install(competitors: 3).map(\.rawValue), ["A", "B", "C"])
    XCTAssertEqual(fixture.installed, Set(["dev.islandstack.competitor.a", "dev.islandstack.competitor.b", "dev.islandstack.competitor.c"]))
    XCTAssertTrue(fixture.activities.isEmpty)
    XCTAssertNil(fixture.foregroundApp)
  }

  func testInstallRejectsCountsOutsideOneToThree() throws {
    let fixture = try HelperFixture()
    defer { fixture.remove() }
    let host = try IslandStackHost(root: fixture.root, udid: "SIMULATOR", process: fixture.process)
    for count in [0, 4] {
      XCTAssertThrowsError(try host.install(competitors: count)) { error in
        guard case HostError.invalidCompetitorCount = error else { return XCTFail("Unexpected error: \(error)") }
      }
    }
    XCTAssertTrue(fixture.installed.isEmpty)
  }

  func testThreeCompetitorsCanStartThenReduceToOneAndStop() throws {
    let fixture = try HelperFixture()
    defer { fixture.remove() }
    let host = try IslandStackHost(root: fixture.root, udid: "SIMULATOR", process: fixture.process)

    let started = try host.start(competitors: 3, returnTo: fixture.target)
    XCTAssertEqual(started.map(\.competitor.rawValue), ["A", "B", "C"])
    XCTAssertEqual(started.map(\.count), [1, 1, 1])

    _ = try host.start(competitors: 1, returnTo: fixture.target)
    XCTAssertEqual(try host.status(returnTo: fixture.target).map(\.count), [1, 0, 0])
    XCTAssertEqual(try host.stop(returnTo: fixture.target).map(\.count), [0, 0, 0])
    XCTAssertEqual(fixture.foregroundApp, fixture.target)
  }
}

private final class HelperFixture {
  let root = FileManager.default.temporaryDirectory.appendingPathComponent("islandstack-three-\(UUID())")
  let target = "dev.test.target"
  var installed: Set<String> = []
  var activities: [String: [String]] = [:]
  var foregroundApp: String?

  init() throws {
    for path in ["ios/Competitor", "ios/Competitor.xcodeproj", "ios/ShortcutDriver.xcodeproj"] {
      try FileManager.default.createDirectory(at: root.appendingPathComponent(path), withIntermediateDirectories: true)
    }
    try Data().write(to: root.appendingPathComponent("ios/Competitor.xcodeproj/project.pbxproj"))
  }

  func remove() { try? FileManager.default.removeItem(at: root) }

  var process: ProcessRunner {
    ProcessRunner { [self] _, args, _ in
      if args == ["-version"] { return "Xcode test fixture" }
      if args.last == "build", let index = args.firstIndex(of: "-configuration") {
        let product = root.appendingPathComponent(".build/islandstack-xcode/Build/Products/\(args[index + 1])-iphonesimulator/Competitor.app")
        try FileManager.default.createDirectory(at: product, withIntermediateDirectories: true)
        return "Built"
      }
      if args.starts(with: ["simctl", "install"]), let path = args.last {
        let configuration = URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent
          .replacingOccurrences(of: "-iphonesimulator", with: "").lowercased()
        installed.insert("dev.islandstack.competitor.\(configuration)")
        return "Installed"
      }
      if args.starts(with: ["simctl", "listapps"]) {
        let apps = Dictionary(uniqueKeysWithValues: installed.union([target]).map { ($0, [String: String]()) })
        return String(decoding: try PropertyListSerialization.data(fromPropertyList: apps, format: .xml, options: 0), as: UTF8.self)
      }
      if args.starts(with: ["simctl", "get_app_container"]), args.count == 5 {
        let bundleID = args[3]
        let container = root.appendingPathComponent("containers/\(bundleID)")
        try FileManager.default.createDirectory(at: container.appendingPathComponent("Documents"), withIntermediateDirectories: true)
        return container.path
      }
      if let method = args.first(where: { $0.hasPrefix("-only-testing:") })?.components(separatedBy: "/").last {
        let identity = "dev.islandstack.competitor.\(method.suffix(1).lowercased())"
        let command = method.dropFirst(4).dropLast().lowercased()
        if command == "start", activities[identity, default: []].isEmpty { activities[identity] = [UUID().uuidString] }
        if command == "stop" { activities[identity] = [] }
        let ids = activities[identity, default: []]
        let receipt: [String: Any] = ["requestID": UUID().uuidString, "command": command,
          "identity": identity, "source": "intent", "count": ids.count, "activityIDs": ids,
          "observedAt": "2026-10-13T12:00:00Z"]
        try JSONSerialization.data(withJSONObject: receipt)
          .write(to: root.appendingPathComponent("containers/\(identity)/Documents/intent-last.json"))
        return "Intent completed"
      }
      if args.starts(with: ["simctl", "launch"]) { foregroundApp = args.last; return "Launched" }
      XCTFail("Unexpected command: \(args)")
      throw SystemProcessError.failed(command: "fixture", exitCode: 1, output: "unexpected command")
    }
  }
}
