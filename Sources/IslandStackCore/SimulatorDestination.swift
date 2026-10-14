import Foundation

public struct SimulatorConfiguration: Equatable {
  public let name: String
  public let deviceTypeIdentifier: String
  public let runtimeIdentifier: String
  public let runtimeName: String

  public init(name: String, deviceTypeIdentifier: String, runtimeIdentifier: String, runtimeName: String) {
    self.name = name
    self.deviceTypeIdentifier = deviceTypeIdentifier
    self.runtimeIdentifier = runtimeIdentifier
    self.runtimeName = runtimeName
  }
}

public enum SimulatorDestination: Equatable {
  case existing(SimulatorDevice)
  case create(SimulatorConfiguration)

  public var title: String {
    switch self {
    case .existing(let device):
      "[\(device.state == "Booted" ? "Running" : "Existing, stopped")] \(device.name) · \(device.runtimeName)"
    case .create(let configuration):
      "[New] \(configuration.name) · \(configuration.runtimeName)"
    }
  }

  public var detail: String {
    switch self {
    case .existing(let device):
      "Reuse this existing Simulator\(device.state == "Booted" ? ", already running" : "; it will be booted before installation"). Device ID: \(device.udid)."
    case .create(let configuration):
      "Create and boot a separate \(configuration.name) with the installed \(configuration.runtimeName) runtime. Choose a model with Dynamic Island to test Island presentation."
    }
  }
}
