import Foundation
import NIO
import NIOHTTP1
import AsyncHTTPClient

public struct QuestDBRequest {
  public var endpoint: PathProviding
  public let headers: HTTPHeaders
  public var body: ByteBuffer?

  public init(
    _ endpoint: PathProviding,
    headers: HTTPHeaders = .init(),
    body: ByteBuffer? = nil
  ) {
    self.endpoint = endpoint
    self.headers = headers
    self.body = body
  }
}

public extension QuestDBRequest {
  func http<T>(
    with config: QuestDBConfig,
    parameters: T? = nil
  ) throws -> HTTPClient.Request
  where T: Encodable {
    var url = "\(config.url)\(endpoint.path)"

    if let parameters = parameters {
      let queryString = try urlEncoder.encode(parameters)
      url.append("?\(queryString)")
    }

    return try HTTPClient.Request(
      url: url,
      method: endpoint.method,
      headers: headers,
      body: nil
    )
  }
}
