import Darwin
import Foundation

public enum SystemProcessError: Error, CustomStringConvertible {
  case timedOut(command: String, seconds: Int)
  case failed(command: String, exitCode: Int32, output: String)

  public var description: String {
    switch self {
    case .timedOut(let command, let seconds):
      "Timed out after \(seconds)s: \(command)"
    case .failed(let command, let exitCode, let output):
      "Command failed (exit \(exitCode)): \(command)\n\(output.suffix(4_000))"
    }
  }
}

public enum SystemProcess {
  @discardableResult
  public static func run(
    _ executable: String,
    arguments: [String],
    directory: URL? = nil,
    timeout: Int = 120
  ) throws -> String {
    let outputURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("islandstack-process-\(UUID().uuidString).log")
    FileManager.default.createFile(atPath: outputURL.path, contents: nil)
    defer { try? FileManager.default.removeItem(at: outputURL) }
    let handle = try FileHandle(forWritingTo: outputURL)
    defer { try? handle.close() }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = directory
    process.standardOutput = handle
    process.standardError = handle

    let finished = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in finished.signal() }
    try process.run()
    let command = ([executable] + arguments).joined(separator: " ")

    if finished.wait(timeout: .now() + .seconds(timeout)) == .timedOut {
      process.terminate()
      if finished.wait(timeout: .now() + .seconds(5)) == .timedOut {
        kill(process.processIdentifier, SIGKILL)
        _ = finished.wait(timeout: .now() + .seconds(5))
      }
      throw SystemProcessError.timedOut(command: command, seconds: timeout)
    }

    let output = String(decoding: try Data(contentsOf: outputURL), as: UTF8.self)
    guard process.terminationStatus == 0 else {
      throw SystemProcessError.failed(
        command: command, exitCode: process.terminationStatus, output: output
      )
    }
    return output
  }
}
