import XCTest
@testable import IslandStackCore

final class ReceiptValidationTests: XCTestCase {
  private let sample = """
    {"requestID":"NEW","command":"start","identity":"dev.islandstack.competitor.a","source":"intent","count":1,"activityIDs":["ACTIVITY"],"error":null,"observedAt":"2026-09-28T09:34:05Z"}
    """.data(using: .utf8)!

  func testStaleReceiptCannotAcknowledgeAnotherInvocation() throws {
    let receipt = try JSONDecoder().decode(IntentReceipt.self, from: sample)
    XCTAssertThrowsError(
      try ReceiptValidation.check(receipt, previousRequestID: "NEW", command: "start", identity: "dev.islandstack.competitor.a")
    ) { error in
      XCTAssertEqual(error as? ReceiptValidationError, .stale)
    }
  }
}
