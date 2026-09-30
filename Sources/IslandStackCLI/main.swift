import Darwin
import Foundation
import IslandStackCore

private enum CLIError: Error, CustomStringConvertible {
  case usage(String)

  var description: String {
    switch self {
    case .usage(let message): message
    }
  }
}

private struct Options {
  let command: String
  var udid: String?
  var returnTo: String?
  var competitors: Int?

  init(arguments: [String]) throws {
    guard let first = arguments.first,
          ["doctor", "start", "status", "stop", "help"].contains(first) else {
      throw CLIError.usage("Expected doctor, start, status, or stop. Run islandstack help.")
    }
    command = first
    var index = 1
    while index < arguments.count {
      let flag = arguments[index]
      guard index + 1 < arguments.count else {
        throw CLIError.usage("Missing value for \(flag).")
      }
      let value = arguments[index + 1]
      switch flag {
      case "--device": udid = value
      case "--return-to": returnTo = value
      case "--competitors":
        guard let number = Int(value) else {
          throw CLIError.usage("--competitors must be 1 or 2.")
        }
        competitors = number
      default: throw CLIError.usage("Unknown option \(flag). Run islandstack help.")
      }
      index += 2
    }
    if command == "start", competitors == nil {
      throw CLIError.usage("start requires --competitors 1 or 2.")
    }
    if ["start", "status", "stop"].contains(command), returnTo == nil {
      throw CLIError.usage("\(command) requires --return-to with the target app's bundle ID.")
    }
    if command != "start", competitors != nil {
      throw CLIError.usage("--competitors is only valid with start.")
    }
  }
}

private func printUsage() {
  print("""
    IslandStack: create competing Live Activities on a booted iPhone Simulator.

    swift run islandstack doctor
    swift run islandstack start --competitors 2 --device <udid> --return-to <target-bundle-id>
    swift run islandstack status --device <udid> --return-to <target-bundle-id>
    swift run islandstack stop --device <udid> --return-to <target-bundle-id>

    Omit --device only when exactly one eligible iPhone Simulator is booted.
    Start, status, and stop briefly open Shortcuts, then launch --return-to.
    """)
}

private func printStates(_ states: [CompetitorState]) {
  for state in states {
    if let count = state.count {
      print("\(state.competitor.rawValue): \(count) active")
    } else {
      print("\(state.competitor.rawValue): not installed")
    }
  }
}

@main
private struct IslandStackCLI {
  static func main() {
    do {
      let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
      if options.command == "help" {
        printUsage()
        return
      }
      let devices = try SimulatorControl.devices()
      if options.command == "doctor" {
        let path = try SystemProcess.run("/usr/bin/xcode-select", arguments: ["-p"], timeout: 20)
        let version = try SystemProcess.run("/usr/bin/xcodebuild", arguments: ["-version"], timeout: 20)
        print("Xcode developer directory: \(path.trimmingCharacters(in: .whitespacesAndNewlines))")
        print(version.trimmingCharacters(in: .whitespacesAndNewlines))
        let eligible = devices.filter(\.isEligible)
        if eligible.isEmpty { print("No eligible booted iPhone Simulators.") }
        for device in eligible {
          print("\(device.name): \(device.udid) [\(device.runtime)]")
        }
        if eligible.count > 1 { print("Pass --device for start, status, or stop.") }
        return
      }

      let selected = try DeviceSelection.choose(from: devices, requestedUDID: options.udid)
      let root = try IslandStackHost.findRoot(
        startingAt: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      )
      let host = try IslandStackHost(root: root, udid: selected.udid)
      let returnTo = options.returnTo!
      print("Simulator: \(selected.name) (\(selected.udid))")
      switch options.command {
      case "start":
        print("Building helpers as needed and invoking Shortcuts actions...")
        printStates(try host.start(competitors: options.competitors!, returnTo: returnTo))
      case "status":
        printStates(try host.status(returnTo: returnTo))
      case "stop":
        printStates(try host.stop(returnTo: returnTo))
      default: break
      }
      print("Returned to \(returnTo).")
    } catch {
      fputs("islandstack: \(error)\n", stderr)
      exit(1)
    }
  }
}
