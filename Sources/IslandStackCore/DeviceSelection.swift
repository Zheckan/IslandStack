import Foundation

public struct SimulatorDevice: Equatable {
  public let name: String
  public let udid: String
  public let state: String
  public let isAvailable: Bool
  public let runtime: String
  public let deviceTypeIdentifier: String?

  public init(
    name: String, udid: String, state: String, isAvailable: Bool, runtime: String,
    deviceTypeIdentifier: String? = nil
  ) {
    self.name = name
    self.udid = udid
    self.state = state
    self.isAvailable = isAvailable
    self.runtime = runtime
    self.deviceTypeIdentifier = deviceTypeIdentifier
  }

  public var isEligible: Bool {
    let runtimeMajor = runtime.components(separatedBy: "SimRuntime.iOS-").last?
      .split(separator: "-").first.flatMap { Int($0) } ?? 0
    let isIPhone = deviceTypeIdentifier?.contains("SimDeviceType.iPhone") ?? name.hasPrefix("iPhone")
    return isIPhone && runtimeMajor >= 17 && isAvailable && state == "Booted"
  }
}

public enum DeviceSelectionError: Error, Equatable, CustomStringConvertible {
  case noBootedIPhone
  case multipleBootedDevices
  case requestedDeviceUnavailable(String)

  public var description: String {
    switch self {
    case .noBootedIPhone:
      "No eligible iPhone Simulator is booted."
    case .multipleBootedDevices:
      "More than one eligible iPhone Simulator is booted; pass --device with a UDID."
    case .requestedDeviceUnavailable(let udid):
      "Simulator \(udid) is not an available, booted iPhone."
    }
  }
}

public enum DeviceSelection {
  public static func choose(from devices: [SimulatorDevice], requestedUDID: String?) throws -> SimulatorDevice {
    let eligible = devices.filter(\.isEligible)
    if let requestedUDID {
      guard let selected = eligible.first(where: { $0.udid == requestedUDID }) else {
        throw DeviceSelectionError.requestedDeviceUnavailable(requestedUDID)
      }
      return selected
    }
    switch eligible.count {
    case 0: throw DeviceSelectionError.noBootedIPhone
    case 1: return eligible[0]
    default: throw DeviceSelectionError.multipleBootedDevices
    }
  }
}
