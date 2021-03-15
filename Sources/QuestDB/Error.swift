import Foundation

public enum QuestDBError: Error {
  case missingConfiguration(String)
  case missingResponseData
  case serverNotFound
  case invalidHost
  case invalidJSON
}

public struct ErrorResponse: Error, Codable {
  public let query: String
  public let error: String
  public let position: Int
}
