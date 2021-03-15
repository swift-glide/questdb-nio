import Foundation
import NIOHTTP1

public protocol PathProviding {
  var method: HTTPMethod { get  }
  var path: String { get }
}

public enum Endpoint: PathProviding {
  case execute

  public var path: String { "/exec" }
  public var method: HTTPMethod { .GET }
}
