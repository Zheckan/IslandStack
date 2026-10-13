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
    let first = arguments.first ?? "install"
    guard ["install", "doctor", "start", "status", "stop", "help"].contains(first) else {
      throw CLIError.usage("Expected install, doctor, start, status, or stop. Run islandstack help.")
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
        guard let number = Int(value), (1...3).contains(number) else {
          throw CLIError.usage("--competitors must be 1, 2, or 3.")
        }
        competitors = number
      default: throw CLIError.usage("Unknown option \(flag). Run islandstack help.")
      }
      index += 2
    }
    if command == "start", competitors == nil {
      throw CLIError.usage("start requires --competitors 1, 2, or 3.")
    }
    if ["start", "status", "stop"].contains(command), returnTo == nil {
      throw CLIError.usage("\(command) requires --return-to with the target app's bundle ID.")
    }
    if !["start", "install"].contains(command), competitors != nil {
      throw CLIError.usage("--competitors is only valid with install or start.")
    }
  }
}

private func printUsage() {
  print("""
    IslandStack: create competing Live Activities on a booted iPhone Simulator.

    npx islandstack
    npx islandstack install --competitors 3 --device <udid>
    npx islandstack doctor
    npx islandstack start --competitors 3 --device <udid> --return-to <target-bundle-id>
    npx islandstack status --device <udid> --return-to <target-bundle-id>
    npx islandstack stop --device <udid> --return-to <target-bundle-id>

    Without a command, choose a booted Simulator and install 1, 2, or 3 helper apps.
    Interactive menus use arrow keys and Enter; Esc or Ctrl+C cancels. Piped input uses numbers.
    Install prompts for missing choices; other commands need --device when multiple iPhones are booted.
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
      var options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
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

      if options.command == "install" {
        if options.udid == nil {
          let eligible = devices.filter(\.isEligible)
          guard !eligible.isEmpty else { throw DeviceSelectionError.noBootedIPhone }
          if eligible.count == 1 {
            options.udid = eligible[0].udid
          } else {
            let choice = try TerminalMenu.choose("Choose a booted iPhone Simulator:",
              options: eligible.map { "\($0.name) [\($0.runtime)]" })
            options.udid = eligible[choice].udid
          }
        }
        // Validate the selected device before asking how many apps to install.
        _ = try DeviceSelection.choose(from: devices, requestedUDID: options.udid)
        if options.competitors == nil {
          options.competitors = try TerminalMenu.choose("How many helper apps? One Live Activity per app:",
            options: ["1 helper app", "2 helper apps", "3 helper apps"]) + 1
        }
      }
      let selected = try DeviceSelection.choose(from: devices, requestedUDID: options.udid)
      let root = try IslandStackHost.findRoot(
        startingAt: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      )
      let host = try IslandStackHost(root: root, udid: selected.udid)
      print("Simulator: \(selected.name) (\(selected.udid))")
      if options.command == "install" {
        print("Building and installing helper apps...")
        for competitor in try host.install(competitors: options.competitors!) {
          print("IslandStack \(competitor.rawValue): installed")
        }
        print("Open each helper app and tap Activate Live Activity. Tap again to stop.")
        return
      }
      let returnTo = options.returnTo!
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
    } catch TerminalMenuError.cancelled {
      fputs("islandstack: Cancelled.\n", stderr)
      exit(130)
    } catch {
      fputs("islandstack: \(error)\n", stderr)
      exit(1)
    }
  }
}
