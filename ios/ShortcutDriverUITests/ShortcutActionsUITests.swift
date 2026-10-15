import XCTest

final class ShortcutActionsUITests: XCTestCase {
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
    try runAction(appName: "IslandStack A", buttonLabel: "Flash")
  }

  @MainActor func testStopA() throws {
    try runAction(appName: "IslandStack A", buttonLabel: "Stop Button In A Circle")
  }

  @MainActor func testStatusA() throws {
    try runAction(appName: "IslandStack A", buttonLabel: "Info")
  }

  @MainActor func testStartB() throws {
    try runAction(appName: "IslandStack B", buttonLabel: "Flame")
  }

  @MainActor func testStopB() throws {
    try runAction(appName: "IslandStack B", buttonLabel: "Stop Button In A Circle")
  }

  @MainActor func testStatusB() throws {
    try runAction(appName: "IslandStack B", buttonLabel: "Info")
  }
}
