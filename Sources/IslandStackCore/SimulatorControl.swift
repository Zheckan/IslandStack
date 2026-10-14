import Foundation

private struct SimctlDeviceList: Decodable {
  let devices: [String: [SimctlDevice]]
}

private struct SimctlDevice: Decodable {
  let name: String
  let udid: String
  let state: String
  let isAvailable: Bool
  let deviceTypeIdentifier: String?
}

private struct SimctlCatalog: Decodable {
  let devices: [String: [SimctlDevice]]
  let devicetypes: [SimctlDeviceType]
  let runtimes: [SimctlRuntime]
}

private struct SimctlDeviceType: Decodable {
  let name: String
  let identifier: String
}

private struct SimctlRuntime: Decodable {
  let name: String
  let identifier: String
  let version: String
  let isAvailable: Bool
  let supportedDeviceTypes: [SimctlDeviceType]?
}

public enum SimulatorControl {
  public static func devices() throws -> [SimulatorDevice] {
    try devices(process: .live)
  }

  static func devices(process: ProcessRunner) throws -> [SimulatorDevice] {
    let output = try process.run(
      "/usr/bin/xcrun", arguments: ["simctl", "list", "devices", "-j"], timeout: 20
    )
    let list = try JSONDecoder().decode(SimctlDeviceList.self, from: Data(output.utf8))
    return devices(from: list.devices)
  }

  private static func devices(from recordsByRuntime: [String: [SimctlDevice]]) -> [SimulatorDevice] {
    recordsByRuntime.flatMap { runtime, records in
      records.map {
        SimulatorDevice(
          name: $0.name, udid: $0.udid, state: $0.state,
          isAvailable: $0.isAvailable, runtime: runtime,
          deviceTypeIdentifier: $0.deviceTypeIdentifier
        )
      }
    }.sorted { ($0.name, $0.udid) < ($1.name, $1.udid) }
  }

  public static func installationDestinations() throws -> [SimulatorDestination] {
    try installationDestinations(process: .live)
  }

  static func installationDestinations(process: ProcessRunner) throws -> [SimulatorDestination] {
    let output = try process.run("/usr/bin/xcrun", arguments: ["simctl", "list", "-j"], timeout: 20)
    let catalog = try JSONDecoder().decode(SimctlCatalog.self, from: Data(output.utf8))
    let existing = devices(from: catalog.devices).filter(\.isEligibleForInstallation).sorted {
      if $0.state != $1.state { return $0.state == "Booted" }
      return ($0.name, $0.udid) < ($1.name, $1.udid)
    }.map { SimulatorDestination.existing($0) }

    let installedTypes = Set(catalog.devicetypes.map(\.identifier))
    let configurations = catalog.runtimes.filter {
      $0.isAvailable && $0.identifier.contains("SimRuntime.iOS-")
        && (Int($0.version.split(separator: ".").first ?? "") ?? 0) >= 17
    }.flatMap { runtime in
      (runtime.supportedDeviceTypes ?? []).filter {
        $0.identifier.contains("SimDeviceType.iPhone") && installedTypes.contains($0.identifier)
      }.map {
        SimulatorConfiguration(name: $0.name, deviceTypeIdentifier: $0.identifier,
          runtimeIdentifier: runtime.identifier, runtimeName: runtime.name)
      }
    }.sorted {
      if $0.runtimeName != $1.runtimeName {
        return $0.runtimeName.compare($1.runtimeName, options: .numeric) == .orderedDescending
      }
      return ($0.name, $0.deviceTypeIdentifier, $0.runtimeIdentifier)
        < ($1.name, $1.deviceTypeIdentifier, $1.runtimeIdentifier)
    }.map { SimulatorDestination.create($0) }
    return existing + configurations
  }

  public static func prepare(_ destination: SimulatorDestination) throws -> SimulatorDevice {
    try prepare(destination, process: .live)
  }

  static func prepare(_ destination: SimulatorDestination, process: ProcessRunner) throws -> SimulatorDevice {
    let udid: String
    switch destination {
    case .existing(let device):
      guard device.isEligibleForInstallation else {
        throw DeviceSelectionError.requestedDeviceUnavailable(device.udid)
      }
      udid = device.udid
    case .create(let configuration):
      udid = try process.run("/usr/bin/xcrun", arguments: [
        "simctl", "create", "Skellige \(configuration.name)",
        configuration.deviceTypeIdentifier, configuration.runtimeIdentifier
      ], timeout: 30).trimmingCharacters(in: .whitespacesAndNewlines)
      guard UUID(uuidString: udid) != nil else { throw SimulatorSetupError.invalidCreatedDeviceID }
    }
    try process.run("/usr/bin/xcrun", arguments: ["simctl", "bootstatus", udid, "-b"], timeout: 300)
    return try DeviceSelection.choose(from: devices(process: process), requestedUDID: udid)
  }

  public static func isInstalled(_ bundleID: String, on udid: String) throws -> Bool {
    try isInstalled(bundleID, on: udid, process: .live)
  }

  static func isInstalled(_ bundleID: String, on udid: String, process: ProcessRunner) throws -> Bool {
    let output = try process.run(
      "/usr/bin/xcrun", arguments: ["simctl", "listapps", udid], timeout: 20
    )
    let list = try PropertyListSerialization.propertyList(
      from: Data(output.utf8), options: [], format: nil
    )
    guard let apps = list as? [String: Any] else {
      throw CocoaError(.propertyListReadCorrupt)
    }
    return apps[bundleID] != nil
  }

  public static func dataContainer(for bundleID: String, on udid: String) throws -> URL {
    try dataContainer(for: bundleID, on: udid, process: .live)
  }

  static func dataContainer(for bundleID: String, on udid: String, process: ProcessRunner) throws -> URL {
    let output = try process.run(
      "/usr/bin/xcrun",
      arguments: ["simctl", "get_app_container", udid, bundleID, "data"],
      timeout: 20
    )
    return URL(fileURLWithPath: output.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  public static func install(_ app: URL, on udid: String) throws {
    try install(app, on: udid, process: .live)
  }

  static func install(_ app: URL, on udid: String, process: ProcessRunner) throws {
    try process.run(
      "/usr/bin/xcrun", arguments: ["simctl", "install", udid, app.path], timeout: 90
    )
  }

  public static func launch(_ bundleID: String, on udid: String) throws {
    try launch(bundleID, on: udid, process: .live)
  }

  static func launch(_ bundleID: String, on udid: String, process: ProcessRunner) throws {
    try process.run(
      "/usr/bin/xcrun", arguments: ["simctl", "launch", udid, bundleID], timeout: 30
    )
  }
}

private enum SimulatorSetupError: Error, CustomStringConvertible {
  case invalidCreatedDeviceID

  var description: String {
    "simctl create did not return a valid Simulator ID."
  }
}
