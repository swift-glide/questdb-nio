import Foundation

public struct QueryResponse: Decodable {
  public struct Column: Decodable {
    var name: String
    var type: String
  }

  public struct Timings: Decodable {
    public var compiler: Int
    public var count: Int
    public var execute: Int
  }

  public var query: String
  public var columns: [Column]
  public var dataset: [[AnyCodable]]
  public var count: Int?
  public var timings: Timings?

  var rows: [[String: Any]] {
    dataset.compactMap { values -> [String: Any]? in
      guard values.count == columns.count else { return nil }

      return values.enumerated().reduce([String: Any]()) { outcome, new in
        var next = outcome
        next[columns[new.offset].name] = new.element.value
        return next
      }
    }
  }

  public func decode<T: Decodable>(_ type: T.Type) throws -> [T] {
    return rows.compactMap {
      try? dictionaryDecoder.decode(T.self, from: $0)
    }
  }
}

public struct QuestOperationResponse: Decodable {
  public var ddl: String

  public init(ddl: String) {
    self.ddl = ddl
  }
}

