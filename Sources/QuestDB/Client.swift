import Foundation
import AsyncHTTPClient
import NIO

let customJSONDecoder: JSONDecoder = {
  let decoder = JSONDecoder()
  return decoder
}()


let dictionaryDecoder: DictionaryDecoder = {
  let decoder = DictionaryDecoder()
  return decoder
}()

let urlEncoder: URLFormEncoder = {
  let encoder = URLFormEncoder()
  return encoder
}()


public final class QuestDBClient {
  public let config: QuestDBConfig
  public let httpClient: HTTPClient

  public init(
    config: QuestDBConfig? = nil,
    httpClient: HTTPClient = .init(
      eventLoopGroupProvider: .createNew
    )
  ) {
    self.config = config ?? .env ?? .default
    self.httpClient = httpClient
  }

  public func syncShutdown() throws {
    try httpClient.syncShutdown()
  }
}

extension QuestDBClient {
  public func execute<T>(
    on eventLoop: EventLoop? = nil,
    options: ExecuteOptions,
    returning: T.Type? = T.self
  ) -> EventLoopFuture<T>
  where T: Decodable {
    let endpoint = Endpoint.execute
    return send(QuestDBRequest(endpoint), on: eventLoop, parameters: options) {
      try customJSONDecoder.decode(T.self, from: $0)
    }
  }

  public func execute<T>(
    on eventLoop: EventLoop? = nil,
    options: ExecuteOptions
  ) -> EventLoopFuture<[T]>
  where T: Codable {
    return execute(on: eventLoop, options: options, returning: QueryResponse.self)
      .flatMapThrowing {
        try $0.decode(T.self)
      }
  }

  private func send<T, U>(
    _ request: QuestDBRequest,
    on eventLoop: EventLoop? = nil,
    parameters: U? = nil,
    transformData: @escaping (ByteBuffer) throws -> T
  ) -> EventLoopFuture<T> where U: Encodable {
    let eventLoopPreference: HTTPClient.EventLoopPreference = {
      if let eventLoop = eventLoop {
        return .delegate(on: eventLoop)
      } else {
        return .indifferent
      }
    }()

    do {
      return httpClient.execute(
        request: try request.http(with: config, parameters: parameters),
        eventLoop: eventLoopPreference
      )
      .flatMapThrowing { apiResponse in
        guard let responseData = apiResponse.body else {
          throw QuestDBError.missingResponseData
        }

        do {
          return try transformData(responseData)
        } catch {
          if let errorResponse = try? customJSONDecoder.decode(
              ErrorResponse.self,
              from: responseData
          ) {
            throw errorResponse
          } else {
            throw error
          }
        }
      }
    } catch {
      return httpClient.eventLoopGroup.next().makeFailedFuture(error)
    }
  }
}

public struct ExecuteOptions: Encodable {
  public var query: String
  public var count: Bool? = false
  public var limit: String? = nil
  public var nm: Bool? = false
  public var timings: Bool? = false

  public init(
    query: String,
    count: Bool? = false,
    limit: String? = nil,
    nm: Bool? = false,
    timings: Bool? = false
  ) {
    self.query = query
    self.count = count
    self.limit = limit
    self.nm = nm
    self.timings = timings
  }
}
