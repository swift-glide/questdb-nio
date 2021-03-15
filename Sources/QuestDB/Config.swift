import Foundation

enum Configkeys: String {
  case url = "QUESTDB_URL"
}

public struct QuestDBConfig {
  /// Don't put a '/' at the end of the host.
  public let url: String

  public init(url: String) {
    self.url = url
  }


  static func fromEnvironmentThrowing() throws -> QuestDBConfig {
    guard let url = Environment[Configkeys.url] else {
      throw QuestDBError.missingConfiguration(Configkeys.url.rawValue)
    }

    return .init(url: url)
  }

  public static var env: QuestDBConfig? {
    do {
      return try fromEnvironmentThrowing()
    } catch {
      debugPrint("QuestDB configuration error: \(error)")
      return nil
    }
  }

  public static var `default`: QuestDBConfig {
    .init(
      url: "http://localhost:9000"
    )
  }

}
