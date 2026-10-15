import Foundation
import XCTest
@testable import IslandStackCore

final class SimulatorSetupTests: XCTestCase {
  private let udid = "C4CDC5CD-A6CA-41E1-8952-080609C8A2F9"

  func testInstallerOrdersRunningThenStoppedThenCompatibleNewDevices() throws {
    let catalog = """
    {
      "devices": {
        "com.apple.CoreSimulator.SimRuntime.iOS-27-0": [
          {"name":"Stopped iPhone","udid":"STOPPED","state":"Shutdown","isAvailable":true,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"},
          {"name":"Running iPhone","udid":"RUNNING","state":"Booted","isAvailable":true,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"},
          {"name":"Unavailable iPhone","udid":"UNAVAILABLE","state":"Booted","isAvailable":false,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"},
          {"name":"iPad","udid":"IPAD","state":"Booted","isAvailable":true,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPad-Pro"}
        ],
        "com.apple.CoreSimulator.SimRuntime.iOS-16-0": [
          {"name":"Old iPhone","udid":"OLD","state":"Booted","isAvailable":true,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-14-Pro"}
        ]
      },
      "devicetypes": [
        {"name":"iPhone 15 Pro","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"},
        {"name":"iPhone 18 Pro","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"},
        {"name":"iPad Pro","identifier":"com.apple.CoreSimulator.SimDeviceType.iPad-Pro"}
      ],
      "runtimes": [
        {"name":"iOS 27.0","identifier":"com.apple.CoreSimulator.SimRuntime.iOS-27-0","version":"27.0","isAvailable":true,"supportedDeviceTypes":[
          {"name":"iPhone 18 Pro","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"},
          {"name":"Uninstalled iPhone","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-missing"},
          {"name":"iPad Pro","identifier":"com.apple.CoreSimulator.SimDeviceType.iPad-Pro"}
        ]},
        {"name":"iOS 18.1","identifier":"com.apple.CoreSimulator.SimRuntime.iOS-18-1","version":"18.1","isAvailable":true,"supportedDeviceTypes":[
          {"name":"iPhone 15 Pro","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"}
        ]},
        {"name":"iOS 28.0","identifier":"com.apple.CoreSimulator.SimRuntime.iOS-28-0","version":"28.0","isAvailable":false,"supportedDeviceTypes":[
          {"name":"iPhone 18 Pro","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"}
        ]},
        {"name":"iOS 16.0","identifier":"com.apple.CoreSimulator.SimRuntime.iOS-16-0","version":"16.0","isAvailable":true,"supportedDeviceTypes":[
          {"name":"iPhone 15 Pro","identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"}
        ]}
      ]
    }
    """
    let process = ProcessRunner { _, arguments, _ in
      XCTAssertEqual(arguments, ["simctl", "list", "-j"])
      return catalog
    }
    let choices = try SimulatorControl.installationDestinations(process: process)
    XCTAssertEqual(choices.map(\.title), [
      "[Running] Running iPhone · iOS 27.0",
      "[Existing, stopped] Stopped iPhone · iOS 27.0",
      "[New] iPhone 18 Pro · iOS 27.0",
      "[New] iPhone 15 Pro · iOS 18.1"
    ])
  }

  func testStoppedDestinationIsBootedBeforeItIsReturned() throws {
    var commands: [[String]] = []
    let process = ProcessRunner { _, arguments, _ in
      commands.append(arguments)
      if arguments[1] == "bootstatus" { return "Finished" }
      return self.inventory()
    }
    let stopped = SimulatorDevice(name: "Playground", udid: udid, state: "Shutdown",
      isAvailable: true, runtime: "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
      deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro")
    let ready = try SimulatorControl.prepare(.existing(stopped), process: process)
    XCTAssertEqual(ready.udid, udid)
    XCTAssertEqual(ready.state, "Booted")
    XCTAssertEqual(commands, [["simctl", "bootstatus", udid, "-b"], ["simctl", "list", "devices", "-j"]])
  }

  func testNewDestinationCreatesAndBootsTheSelectedModelAndRuntime() throws {
    var commands: [[String]] = []
    let process = ProcessRunner { _, arguments, _ in
      commands.append(arguments)
      switch arguments[1] {
      case "create": return self.udid + "\n"
      case "bootstatus": return "Finished"
      default: return self.inventory()
      }
    }
    let configuration = SimulatorConfiguration(name: "iPhone 15 Pro",
      deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro",
      runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0", runtimeName: "iOS 27.0")
    let ready = try SimulatorControl.prepare(.create(configuration), process: process)
    XCTAssertEqual(ready.udid, udid)
    XCTAssertTrue(ready.isEligible)
    XCTAssertEqual(commands, [
      ["simctl", "create", "Skellige iPhone 15 Pro", configuration.deviceTypeIdentifier, configuration.runtimeIdentifier],
      ["simctl", "bootstatus", udid, "-b"],
      ["simctl", "list", "devices", "-j"]
    ])
  }

  func testCreationFailureDoesNotBootAnotherDevice() {
    var commands: [[String]] = []
    let process = ProcessRunner { _, arguments, _ in
      commands.append(arguments)
      return "not a simulator ID"
    }
    let configuration = SimulatorConfiguration(name: "iPhone 15 Pro",
      deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro",
      runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-27-0", runtimeName: "iOS 27.0")
    XCTAssertThrowsError(try SimulatorControl.prepare(.create(configuration), process: process))
    XCTAssertEqual(commands.count, 1)
    XCTAssertEqual(commands.first?[1], "create")
  }

  private func inventory() -> String {
    """
    {"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[
      {"name":"Playground","udid":"\(udid)","state":"Booted","isAvailable":true,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"}
    ]}}
    """
  }
}
