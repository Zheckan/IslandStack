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
      throw CLIError.usage("Expected install, doctor, start, status, or stop. Run skellige help.")
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
      default: throw CLIError.usage("Unknown option \(flag). Run skellige help.")
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
    Skellige: start rival Live Activities on a booted iPhone Simulator.

    npx skellige
    npx skellige install --competitors 3 --device <udid>
    npx skellige doctor
    npx skellige start --competitors 3 --device <udid> --return-to <target-bundle-id>
    npx skellige status --device <udid> --return-to <target-bundle-id>
    npx skellige stop --device <udid> --return-to <target-bundle-id>

    Without a command, choose a running, stopped, or new Simulator and install 1, 2, or 3 helper apps.
    Interactive menus use arrows or J/K and Enter. Esc goes back; Q or Ctrl+C cancels.
    Esc cancels on the first screen. Piped input uses numbers.
    Install boots or creates the selected Simulator using an installed iOS 17+ runtime.
    Other commands need a booted Simulator and --device when multiple iPhones are booted.
    Start, status, and stop briefly open Shortcuts, then launch --return-to.
    """)
}

private func printStates(_ states: [CompetitorState]) {
  for state in states {
    if let count = state.count {
      print("\(state.competitor.name): \(count) active")
    } else {
      print("\(state.competitor.name): not installed")
    }
  }
  if states.count == Competitor.allCases.count, states.allSatisfy({ ($0.count ?? 0) > 0 }) {
    print("The Skellige throne is contested.")
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

      var installationDestination: SimulatorDestination?
      if options.command == "install" {
        let destinations: [SimulatorDestination]
        if let udid = options.udid {
          guard let device = devices.first(where: { $0.udid == udid && $0.isEligibleForInstallation }) else {
            throw CLIError.usage("Simulator \(udid) is not an available iPhone with iOS 17 or newer.")
          }
          destinations = [.existing(device)]
        } else {
          destinations = try SimulatorControl.installationDestinations()
        }
        guard !destinations.isEmpty else {
          throw CLIError.usage("No eligible iPhone Simulators or installed iOS 17+ runtimes. Install an iOS runtime in Xcode first.")
        }
        let allowsDeviceChoice = options.udid == nil
        var previousChoice = 0
        while true {
          if allowsDeviceChoice {
            let choice = try TerminalMenu.choose("Choose an iPhone Simulator:", options: destinations.map {
              TerminalMenuOption(title: $0.title, description: $0.detail)
            }, initialChoice: previousChoice)
            previousChoice = choice
            installationDestination = destinations[choice]
          } else {
            installationDestination = destinations[0]
          }
          if options.competitors == nil {
            do {
              options.competitors = try TerminalMenu.choose("How many helper apps? One Live Activity per app:",
                options: [
                  TerminalMenuOption(title: "1 helper app", description: "Install An Craite. Tap its Activate Live Activity button to start one activity. Installation leaves existing apps and activities alone."),
                  TerminalMenuOption(title: "2 helper apps", description: "Install An Craite and Tordarroch. Each app can start one activity. iOS chooses which activities appear in the Dynamic Island."),
                  TerminalMenuOption(title: "3 helper apps", description: "Install An Craite, Tordarroch, and Drummond. Each app can start one activity. Three active activities do not guarantee three visible Island items.")
                ], allowsBack: allowsDeviceChoice) + 1
            } catch TerminalMenuError.back {
              continue
            }
          }
          break
        }
      }
      let selected: SimulatorDevice
      let root: URL
      let caller = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
      if let destination = installationDestination {
        // Validate the source before creating or booting a Simulator.
        root = try IslandStackHost.findRoot(startingAt: caller)
        switch destination {
        case .existing(let device):
          print(device.state == "Booted" ? "Using running Simulator: \(device.name)" : "Booting existing Simulator: \(device.name)...")
        case .create(let configuration):
          print("Creating and booting \(configuration.name) · \(configuration.runtimeName)...")
        }
        selected = try SimulatorControl.prepare(destination)
      } else {
        selected = try DeviceSelection.choose(from: devices, requestedUDID: options.udid)
        root = try IslandStackHost.findRoot(startingAt: caller)
      }
      let host = try IslandStackHost(root: root, udid: selected.udid)
      print("Simulator: \(selected.name) (\(selected.udid))")
      if options.command == "install" {
        print("Building and installing helper apps...")
        for competitor in try host.install(competitors: options.competitors!) {
          print("\(competitor.name): installed")
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
      fputs("skellige: Cancelled.\n", stderr)
      exit(130)
    } catch {
      fputs("skellige: \(error)\n", stderr)
      exit(1)
    }
  }
}
