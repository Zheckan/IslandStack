import XCTest
@testable import IslandStackCore

final class DeviceSelectionTests: XCTestCase {
  private let devices = [
    SimulatorDevice(name: "iPhone 15 Pro", udid: "AAAA", state: "Booted", isAvailable: true, runtime: "com.apple.CoreSimulator.SimRuntime.iOS-27-0"),
    SimulatorDevice(name: "iPhone 18 Pro", udid: "BBBB", state: "Booted", isAvailable: true, runtime: "com.apple.CoreSimulator.SimRuntime.iOS-27-0"),
    SimulatorDevice(name: "iPhone 18 Pro", udid: "CCCC", state: "Shutdown", isAvailable: true, runtime: "com.apple.CoreSimulator.SimRuntime.iOS-27-0")
  ]

  func testMultipleBootedIPhonesRequireExplicitUDID() throws {
    XCTAssertThrowsError(try DeviceSelection.choose(from: devices, requestedUDID: nil)) { error in
      XCTAssertEqual(error as? DeviceSelectionError, .multipleBootedDevices)
    }
  }

  func testExplicitUDIDSelectsOnlyBootedDevice() throws {
    XCTAssertEqual(try DeviceSelection.choose(from: devices, requestedUDID: "BBBB").udid, "BBBB")
    XCTAssertThrowsError(try DeviceSelection.choose(from: devices, requestedUDID: "CCCC"))
  }

  func testSingleBootedIPhoneIsSelectedAutomatically() throws {
    let one = devices.filter { $0.udid != "BBBB" }
    XCTAssertEqual(try DeviceSelection.choose(from: one, requestedUDID: nil).udid, "AAAA")
  }

  func testCustomNamedIPhoneUsesDeviceType() throws {
    let custom = SimulatorDevice(
      name: "IslandStack playground", udid: "DDDD", state: "Booted", isAvailable: true,
      runtime: "com.apple.CoreSimulator.SimRuntime.iOS-27-0",
      deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-15-Pro"
    )
    XCTAssertEqual(try DeviceSelection.choose(from: [custom], requestedUDID: nil).udid, "DDDD")
  }
}
