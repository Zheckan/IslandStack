import XCTest

final class ShortcutActionsUITests: XCTestCase {
  @MainActor func testCompactIslandFitsStatusBar() {
    let app = XCUIApplication(bundleIdentifier: "dev.islandstack.competitor.a")
    app.launchArguments = ["stop", UUID().uuidString]
    app.launch()
    XCTAssertTrue(app.buttons["Activate Live Activity"].waitForExistence(timeout: 10))
    defer {
      app.launchArguments = ["stop", UUID().uuidString]
      app.launch()
    }

    app.launchArguments = ["start", UUID().uuidString]
    app.launch()
    XCTAssertTrue(app.buttons["Stop Live Activity"].waitForExistence(timeout: 10))
    XCUIDevice.shared.press(.home)

    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let island = springboard.otherElements.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "jindo-container-view:")
    ).firstMatch
    XCTAssertTrue(island.waitForExistence(timeout: 10))
    XCTAssertLessThan(island.frame.width, 250, "Compact Island occupies most of the top bar")

    let timer = island.staticTexts.matching(
      NSPredicate(format: "label MATCHES %@", "[0-9]{1,2}:[0-9]{2}")
    ).firstMatch
    XCTAssertTrue(timer.waitForExistence(timeout: 10))
    XCTAssertLessThanOrEqual(timer.frame.width, 45, "Compact timer exceeds its allotted width")
  }

  @MainActor
  private func runAction(appName: String, buttonLabel: String) throws {
    let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
    shortcuts.launch()

    let ok = shortcuts.buttons["OK"]
    if ok.waitForExistence(timeout: 2) { ok.tap() }
    let onboarding = shortcuts.buttons["Continue"]
    if onboarding.waitForExistence(timeout: 2) { onboarding.tap() }

    let app = shortcuts.buttons[appName]
    for _ in 0..<4 {
      if app.waitForExistence(timeout: 2) { break }
      let library = shortcuts.buttons["Library"]
      guard library.exists else { break }
      let start = shortcuts.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5))
      let end = shortcuts.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
      start.press(forDuration: 0.05, thenDragTo: end)
    }
    guard app.waitForExistence(timeout: 5) else {
      XCTFail("Could not find \(appName) in Shortcuts: \(shortcuts.debugDescription)")
      return
    }
    app.tap()

    let action = shortcuts.buttons[buttonLabel]
    guard action.waitForExistence(timeout: 10) else {
      XCTFail("Could not find \(buttonLabel) in Shortcuts: \(shortcuts.debugDescription)")
      return
    }
    action.tap()
  }

  @MainActor func testStartA() throws {
    try runAction(appName: "An Craite", buttonLabel: "Flash")
  }

  @MainActor func testStopA() throws {
    try runAction(appName: "An Craite", buttonLabel: "Stop Button In A Circle")
  }

  @MainActor func testStatusA() throws {
    try runAction(appName: "An Craite", buttonLabel: "Info")
  }

  @MainActor func testStartB() throws {
    try runAction(appName: "Tordarroch", buttonLabel: "Flame")
  }

  @MainActor func testStopB() throws {
    try runAction(appName: "Tordarroch", buttonLabel: "Stop Button In A Circle")
  }

  @MainActor func testStatusB() throws {
    try runAction(appName: "Tordarroch", buttonLabel: "Info")
  }

  @MainActor func testStartC() throws {
    try runAction(appName: "Drummond", buttonLabel: "Do Not Disturb")
  }

  @MainActor func testStopC() throws {
    try runAction(appName: "Drummond", buttonLabel: "Stop Button In A Circle")
  }

  @MainActor func testStatusC() throws {
    try runAction(appName: "Drummond", buttonLabel: "Info")
  }
}
