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

public enum SimulatorControl {
  public static func devices() throws -> [SimulatorDevice] {
    let output = try SystemProcess.run(
      "/usr/bin/xcrun", arguments: ["simctl", "list", "devices", "-j"], timeout: 20
    )
    let list = try JSONDecoder().decode(SimctlDeviceList.self, from: Data(output.utf8))
    return list.devices.flatMap { runtime, records in
      records.map {
        SimulatorDevice(
          name: $0.name, udid: $0.udid, state: $0.state,
          isAvailable: $0.isAvailable, runtime: runtime,
          deviceTypeIdentifier: $0.deviceTypeIdentifier
        )
      }
    }.sorted { ($0.name, $0.udid) < ($1.name, $1.udid) }
  }

  public static func isInstalled(_ bundleID: String, on udid: String) -> Bool {
    (try? SystemProcess.run(
      "/usr/bin/xcrun", arguments: ["simctl", "appinfo", udid, bundleID], timeout: 20
    )) != nil
  }

  public static func dataContainer(for bundleID: String, on udid: String) throws -> URL {
    let output = try SystemProcess.run(
      "/usr/bin/xcrun",
      arguments: ["simctl", "get_app_container", udid, bundleID, "data"],
      timeout: 20
    )
    return URL(fileURLWithPath: output.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  public static func install(_ app: URL, on udid: String) throws {
    try SystemProcess.run(
      "/usr/bin/xcrun", arguments: ["simctl", "install", udid, app.path], timeout: 90
    )
  }

  public static func launch(_ bundleID: String, on udid: String) throws {
    try SystemProcess.run(
      "/usr/bin/xcrun", arguments: ["simctl", "launch", udid, bundleID], timeout: 30
    )
  }
}
