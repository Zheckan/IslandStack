import Foundation

public struct IntentReceipt: Decodable, Equatable {
  public let requestID: String
  public let command: String
  public let identity: String
  public let source: String
  public let count: Int
  public let activityIDs: [String]
  public let error: String?
  public let observedAt: String
}

public enum ReceiptValidationError: Error, Equatable, CustomStringConvertible {
  case stale
  case wrongCommand
  case wrongIdentity
  case wrongSource
  case inconsistentCount
  case intentError(String)

  public var description: String {
    switch self {
    case .stale: "The helper did not write a fresh receipt."
    case .wrongCommand: "The helper receipt acknowledged a different command."
    case .wrongIdentity: "The helper receipt came from a different app."
    case .wrongSource: "The helper receipt did not come from its App Intent."
    case .inconsistentCount: "The helper receipt's activity count disagrees with its IDs."
    case .intentError(let message): "The helper reported: \(message)"
    }
  }
}

public enum ReceiptValidation {
  public static func check(
    _ receipt: IntentReceipt,
    previousRequestID: String?,
    command: String,
    identity: String
  ) throws {
    guard receipt.requestID != previousRequestID else { throw ReceiptValidationError.stale }
    guard receipt.command == command else { throw ReceiptValidationError.wrongCommand }
    guard receipt.identity == identity else { throw ReceiptValidationError.wrongIdentity }
    guard receipt.source == "intent" else { throw ReceiptValidationError.wrongSource }
    guard receipt.count == receipt.activityIDs.count else { throw ReceiptValidationError.inconsistentCount }
    if let error = receipt.error { throw ReceiptValidationError.intentError(error) }
  }
}
