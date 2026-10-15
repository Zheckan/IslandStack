import Foundation
import XCTest
@testable import IslandStackCore

final class SimulatorInspectionTests: XCTestCase {
  func testSuccessfulInventoryDistinguishesInstalledAndAbsentApps() throws {
    let process = ProcessRunner { _, _, _ in
      // simctl emits an OpenStep property list on current Xcode versions.
      """
      {
        "dev.test.installed" = {
          CFBundleIdentifier = "dev.test.installed";
        };
      }
      """
    }
    XCTAssertTrue(try SimulatorControl.isInstalled("dev.test.installed", on: "SIMULATOR", process: process))
    XCTAssertFalse(try SimulatorControl.isInstalled("dev.test.absent", on: "SIMULATOR", process: process))
  }

  func testMalformedInventoryCannotBeReportedAsAppAbsent() {
    for output in ["service unavailable", "()"] {
      let process = ProcessRunner { _, _, _ in output }
      XCTAssertThrowsError(
        try SimulatorControl.isInstalled("dev.test.absent", on: "SIMULATOR", process: process)
      )
    }
  }
}
