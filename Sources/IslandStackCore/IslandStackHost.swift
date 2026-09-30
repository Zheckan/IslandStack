import CryptoKit
import Foundation

public enum Competitor: String, CaseIterable, Sendable {
  case a = "A"
  case b = "B"

  public var bundleID: String { "dev.islandstack.competitor.\(rawValue.lowercased())" }
}

public enum HelperAction: String, Sendable {
  case start, status, stop

  func testMethod(for competitor: Competitor) -> String {
    "test\(rawValue.capitalized)\(competitor.rawValue)"
  }
}

public enum HostError: Error, CustomStringConvertible {
  case missingProject
  case missingBuild(URL)
  case missingReceipt(Competitor, HelperAction)
  case invalidCompetitorCount
  case targetNotInstalled(String)
  case unexpectedCount(Competitor, HelperAction, Int)
  case partialStart(String)
  case partialStop(String)

  public var description: String {
    switch self {
    case .missingProject: "Run this command from an IslandStack source checkout."
    case .missingBuild(let path): "Xcode did not produce \(path.path)."
    case .missingReceipt(let competitor, let action):
      "\(competitor.rawValue) did not acknowledge \(action.rawValue) within 30 seconds."
    case .invalidCompetitorCount: "--competitors must be 1 or 2."
    case .targetNotInstalled(let bundleID):
      "Return app \(bundleID) is not installed on the selected Simulator."
    case .unexpectedCount(let competitor, let action, let count):
      "\(competitor.rawValue) reported \(count) activities after \(action.rawValue)."
    case .partialStart(let message): message
    case .partialStop(let message): message
    }
  }
}

public struct CompetitorState {
  public let competitor: Competitor
  public let installed: Bool
  public let count: Int?

  public init(competitor: Competitor, installed: Bool, count: Int?) {
    self.competitor = competitor
    self.installed = installed
    self.count = count
  }
}

public final class IslandStackHost {
  public let root: URL
  public let udid: String
  private let cache: URL
  private let xcodeVersion: String
  private let process: ProcessRunner

  public convenience init(root: URL, udid: String) throws {
    try self.init(root: root, udid: udid, process: .live)
  }

  init(root: URL, udid: String, process: ProcessRunner) throws {
    self.process = process
    self.root = root
    self.udid = udid
    self.cache = root.appendingPathComponent(".build/islandstack-xcode")
    guard FileManager.default.fileExists(atPath: root.appendingPathComponent("ios/Competitor.xcodeproj").path),
          FileManager.default.fileExists(atPath: root.appendingPathComponent("ios/ShortcutDriver.xcodeproj").path)
    else { throw HostError.missingProject }
    xcodeVersion = try process.run("/usr/bin/xcodebuild", arguments: ["-version"], timeout: 20)
  }

  public static func findRoot(startingAt start: URL) throws -> URL {
    var candidate = start.standardizedFileURL
    while true {
      if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path),
         FileManager.default.fileExists(atPath: candidate.appendingPathComponent("ios/Competitor.xcodeproj").path) {
        return candidate
      }
      let parent = candidate.deletingLastPathComponent()
      if parent == candidate { throw HostError.missingProject }
      candidate = parent
    }
  }

  public func start(competitors: Int, returnTo bundleID: String) throws -> [CompetitorState] {
    guard (1...2).contains(competitors) else { throw HostError.invalidCompetitorCount }
    try validateReturnApp(bundleID)
    return try withReturn(to: bundleID) {
      if competitors == 1, try SimulatorControl.isInstalled(Competitor.b.bundleID, on: udid, process: process) {
        let stopped = try run(.stop, for: .b)
        guard stopped.count == 0 else { throw HostError.unexpectedCount(.b, .stop, stopped.count) }
      }
      try prepare(.a)
      let a = try run(.start, for: .a)
      guard a.count == 1 else { throw HostError.unexpectedCount(.a, .start, a.count) }
      if competitors == 1 {
        return [CompetitorState(competitor: .a, installed: true, count: 1)]
      }
      do {
        try prepare(.b)
        let b = try run(.start, for: .b)
        guard b.count == 1 else { throw HostError.unexpectedCount(.b, .start, b.count) }
      } catch {
        let aStatus = try? run(.status, for: .a)
        let description = aStatus.map { "A currently reports \($0.count) activity. " } ?? "A's current state could not be verified. "
        throw HostError.partialStart("B failed to start. \(description)Run stop to clean up. Cause: \(error)")
      }
      return [
        CompetitorState(competitor: .a, installed: true, count: 1),
        CompetitorState(competitor: .b, installed: true, count: 1)
      ]
    }
  }

  public func status(returnTo bundleID: String) throws -> [CompetitorState] {
    try validateReturnApp(bundleID)
    return try withReturn(to: bundleID) {
      try Competitor.allCases.map { competitor in
        guard try SimulatorControl.isInstalled(competitor.bundleID, on: udid, process: process) else {
          return CompetitorState(competitor: competitor, installed: false, count: nil)
        }
        let receipt = try run(.status, for: competitor)
        return CompetitorState(competitor: competitor, installed: true, count: receipt.count)
      }
    }
  }

  public func stop(returnTo bundleID: String) throws -> [CompetitorState] {
    try validateReturnApp(bundleID)
    return try withReturn(to: bundleID) {
      var states: [CompetitorState] = []
      var failures: [String] = []
      for competitor in Competitor.allCases {
        do {
          guard try SimulatorControl.isInstalled(competitor.bundleID, on: udid, process: process) else {
            states.append(CompetitorState(competitor: competitor, installed: false, count: nil))
            continue
          }
          let receipt = try run(.stop, for: competitor)
          guard receipt.count == 0 else {
            throw HostError.unexpectedCount(competitor, .stop, receipt.count)
          }
          states.append(CompetitorState(competitor: competitor, installed: true, count: 0))
        } catch {
          failures.append("\(competitor.rawValue): \(error)")
        }
      }
      if !failures.isEmpty {
        let stopped = states.filter { $0.installed && $0.count == 0 }
          .map { $0.competitor.rawValue }.joined(separator: ", ")
        throw HostError.partialStop("Stop failed for \(failures.joined(separator: "; ")). "
          + "Stopped: \(stopped.isEmpty ? "none" : stopped). Run status to verify remaining activities.")
      }
      return states
    }
  }

  private func validateReturnApp(_ bundleID: String) throws {
    guard try SimulatorControl.isInstalled(bundleID, on: udid, process: process) else {
      throw HostError.targetNotInstalled(bundleID)
    }
  }

  private func withReturn<T>(to bundleID: String, body: () throws -> T) throws -> T {
    let result: T
    do {
      result = try body()
    } catch {
      try? SimulatorControl.launch(bundleID, on: udid, process: process)
      throw error
    }
    try SimulatorControl.launch(bundleID, on: udid, process: process)
    return result
  }

  private func fingerprint(for competitor: Competitor) throws -> String {
    let source = root.appendingPathComponent("ios/Competitor")
    let paths = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
      .filter { ["swift", "plist"].contains($0.pathExtension) }
      + [root.appendingPathComponent("ios/Competitor.xcodeproj/project.pbxproj")]
    var hasher = SHA256()
    hasher.update(data: Data(xcodeVersion.utf8))
    hasher.update(data: Data(competitor.rawValue.utf8))
    for path in paths.sorted(by: { $0.path < $1.path }) {
      hasher.update(data: Data(path.lastPathComponent.utf8))
      hasher.update(data: try Data(contentsOf: path))
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }

  private func prepare(_ competitor: Competitor) throws {
    let fingerprint = try fingerprint(for: competitor)
    let product = cache.appendingPathComponent(
      "Build/Products/\(competitor.rawValue)-iphonesimulator/Competitor.app"
    )
    try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
    let buildMarker = cache.appendingPathComponent("build-\(competitor.rawValue).txt")
    if (try? String(contentsOf: buildMarker, encoding: .utf8)) != fingerprint
      || !FileManager.default.fileExists(atPath: product.path) {
      try process.run(
        "/usr/bin/xcodebuild",
        arguments: [
          "-project", root.appendingPathComponent("ios/Competitor.xcodeproj").path,
          "-scheme", "Competitor", "-configuration", competitor.rawValue,
          "-sdk", "iphonesimulator", "-destination", "platform=iOS Simulator,id=\(udid)",
          "-derivedDataPath", cache.path, "CODE_SIGNING_ALLOWED=NO", "build"
        ], timeout: 240
      )
      guard FileManager.default.fileExists(atPath: product.path) else {
        throw HostError.missingBuild(product)
      }
      try fingerprint.write(to: buildMarker, atomically: true, encoding: .utf8)
    }
    let installMarker = cache.appendingPathComponent("installed-\(udid)-\(competitor.rawValue).txt")
    if try (try? String(contentsOf: installMarker, encoding: .utf8)) != fingerprint
      || !SimulatorControl.isInstalled(competitor.bundleID, on: udid, process: process) {
      try SimulatorControl.install(product, on: udid, process: process)
      try fingerprint.write(to: installMarker, atomically: true, encoding: .utf8)
    }
  }

  private func run(_ action: HelperAction, for competitor: Competitor) throws -> IntentReceipt {
    let receiptURL = try SimulatorControl.dataContainer(for: competitor.bundleID, on: udid, process: process)
      .appendingPathComponent("Documents/intent-last.json")
    let decoder = JSONDecoder()
    let previous = (try? Data(contentsOf: receiptURL))
      .flatMap { try? decoder.decode(IntentReceipt.self, from: $0) }?.requestID

    try process.run(
      "/usr/bin/xcodebuild",
      arguments: [
        "-project", root.appendingPathComponent("ios/ShortcutDriver.xcodeproj").path,
        "-scheme", "ShortcutDriver", "-configuration", "Release",
        "-sdk", "iphonesimulator", "-destination", "platform=iOS Simulator,id=\(udid)",
        "-derivedDataPath", cache.appendingPathComponent("Driver").path,
        "-parallel-testing-enabled", "NO", "-test-timeouts-enabled", "YES",
        "-maximum-test-execution-time-allowance", "90", "CODE_SIGNING_ALLOWED=NO",
        "-only-testing:ShortcutDriverUITests/ShortcutActionsUITests/\(action.testMethod(for: competitor))",
        "test"
      ], timeout: 180
    )

    let deadline = Date().addingTimeInterval(30)
    repeat {
      if let data = try? Data(contentsOf: receiptURL),
         let receipt = try? decoder.decode(IntentReceipt.self, from: data),
         receipt.requestID != previous {
        try ReceiptValidation.check(
          receipt, previousRequestID: previous,
          command: action.rawValue, identity: competitor.bundleID
        )
        return receipt
      }
      Thread.sleep(forTimeInterval: 0.2)
    } while Date() < deadline
    throw HostError.missingReceipt(competitor, action)
  }
}
