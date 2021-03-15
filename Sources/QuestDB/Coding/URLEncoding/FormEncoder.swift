/// The MIT License (MIT)
///
/// Copyright (c) 2020 Qutheory, LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.
///
/// Courtesy of https://github.com/vapor/vapor

import Foundation

/// Encodes `Encodable` instances to `application/x-www-form-urlencoded` data.
///
///     print(user) /// User
///     let data = try URLFormEncoder().encode(user)
///     print(data) /// Data
///
/// URL-encoded forms are commonly used by websites to send form data via POST requests. This encoding is relatively
/// efficient for small amounts of data but must be percent-encoded.  `multipart/form-data` is more efficient for sending
/// large data blobs like files.
///
/// See [Mozilla's](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/POST) docs for more information about
/// url-encoded forms.
struct URLFormEncoder {
  /// Used to capture URLForm Coding Configuration used for encoding.
  struct Configuration {
    /// Supported array encodings.
    enum ArrayEncoding {
      /// Arrays are serialized as separate values with bracket suffixed keys.
      /// For example, `foo = [1,2,3]` would be serialized as `foo[]=1&foo[]=2&foo[]=3`.
      case bracket
      /// Arrays are serialized as a single value with character-separated items.
      /// For example, `foo = [1,2,3]` would be serialized as `foo=1,2,3`.
      case separator(Character)
      /// Arrays are serialized as separate values.
      /// For example, `foo = [1,2,3]` would be serialized as `foo=1&foo=2&foo=3`.
      case values
    }

    /// Supported date formats
    enum DateEncodingStrategy {
      /// Seconds since 1 January 1970 00:00:00 UTC (Unix Timestamp)
      case secondsSince1970
      /// ISO 8601 formatted date
      case iso8601
      /// Using custom callback
      case custom((Date, Encoder) throws -> Void)
    }
    /// Specified array encoding.
    var arrayEncoding: ArrayEncoding
    var dateEncodingStrategy: DateEncodingStrategy

    /// Creates a new `Configuration`.
    ///
    ///  - parameters:
    ///     - arrayEncoding: Specified array encoding. Defaults to `.bracket`.
    ///     - dateFormat: Format to encode date format too. Defaults to `secondsSince1970`
    init(
      arrayEncoding: ArrayEncoding = .bracket,
      dateEncodingStrategy: DateEncodingStrategy = .secondsSince1970
    ) {
      self.arrayEncoding = arrayEncoding
      self.dateEncodingStrategy = dateEncodingStrategy
    }
  }

  private let configuration: Configuration

  /// Create a new `URLFormEncoder`.
  ///
  ///        ContentConfiguration.global.use(urlEncoder: URLFormEncoder(bracketsAsArray: true, flagsAsBool: true, arraySeparator: nil))
  ///
  /// - parameters:
  ///    - configuration: Defines how encoding is done see `URLEncodedFormCodingConfig` for more information
  init(
    configuration: Configuration = .init()
  ) {
    self.configuration = configuration
  }

  /// Encodes the supplied `Encodable` object to `Data`.
  ///
  ///     print(user) // User
  ///     let data = try URLFormEncoder().encode(user)
  ///     print(data) // "name=Vapor&age=3"
  ///
  /// - parameters:
  ///     - encodable: Generic `Encodable` object (`E`) to encode.
  ///     - configuration: Overwrides the  coding config for this encoding call.
  /// - returns: Encoded `Data`
  /// - throws: Any error that may occur while attempting to encode the specified type.
  func encode<E>(_ encodable: E) throws -> String
  where E: Encodable
  {
    let encoder = _Encoder(codingPath: [], configuration: self.configuration)
    try encodable.encode(to: encoder)
    let serializer = URLEncodedFormSerializer()
    return try serializer.serialize(encoder.getData())
  }
}

// MARK: Private
private protocol _Container {
  func getData() throws -> URLEncodedFormData
}

private class _Encoder: Encoder {

  var codingPath: [CodingKey]
  private var container: _Container? = nil

  func getData() throws -> URLEncodedFormData {
    return try container?.getData() ?? []
  }

  var userInfo: [CodingUserInfoKey: Any] {
    return [:]
  }

  private let configuration: URLFormEncoder.Configuration

  init(codingPath: [CodingKey], configuration: URLFormEncoder.Configuration) {
    self.codingPath = codingPath
    self.configuration = configuration
  }

  func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
    let container = KeyedContainer<Key>(codingPath: codingPath, configuration: configuration)
    self.container = container
    return .init(container)
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    let container = UnkeyedContainer(codingPath: codingPath, configuration: configuration)
    self.container = container
    return container
  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    let container = SingleValueContainer(codingPath: codingPath, configuration: configuration)
    self.container = container
    return container
  }

  private final class KeyedContainer<Key>: KeyedEncodingContainerProtocol, _Container
  where Key: CodingKey
  {
    var codingPath: [CodingKey]
    var internalData: URLEncodedFormData = []
    var childContainers: [String: _Container] = [:]

    func getData() throws -> URLEncodedFormData {
      var result = internalData
      for (key, childContainer) in self.childContainers {
        result.children[key] = try childContainer.getData()
      }
      return result
    }

    private let configuration: URLFormEncoder.Configuration

    init(
      codingPath: [CodingKey],
      configuration: URLFormEncoder.Configuration
    ) {
      self.codingPath = codingPath
      self.configuration = configuration
    }

    /// See `KeyedEncodingContainerProtocol`
    func encodeNil(forKey key: Key) throws {
      // skip
    }

    private func encodeDate(_ date: Date, forKey key: Key) throws {
      switch configuration.dateEncodingStrategy {
      case .secondsSince1970:
        internalData.children[key.stringValue] = URLEncodedFormData(values: [date.urlQueryFragmentValue])
      case .iso8601:
        internalData.children[key.stringValue] = URLEncodedFormData(values: [
          ISO8601DateFormatter.threadSpecific.string(from: date).urlQueryFragmentValue
        ])
      case .custom(let callback):
        let encoder = _Encoder(codingPath: self.codingPath + [key], configuration: self.configuration)
        try callback(date, encoder)
        self.internalData.children[key.stringValue] = try encoder.getData()
      }
    }

    /// See `KeyedEncodingContainerProtocol`
    func encode<T>(_ value: T, forKey key: Key) throws
    where T : Encodable
    {
      if let date = value as? Date {
        try encodeDate(date, forKey: key)
      } else if let convertible = value as? URLQueryFragmentConvertible {
        internalData.children[key.stringValue] = URLEncodedFormData(values: [convertible.urlQueryFragmentValue])
      } else {
        let encoder = _Encoder(codingPath: self.codingPath + [key], configuration: self.configuration)
        try value.encode(to: encoder)
        self.internalData.children[key.stringValue] = try encoder.getData()
      }
    }

    /// See `KeyedEncodingContainerProtocol`
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey>
    where NestedKey: CodingKey
    {
      let container = KeyedContainer<NestedKey>(
        codingPath: self.codingPath + [key],
        configuration: self.configuration
      )
      self.childContainers[key.stringValue] = container
      return .init(container)
    }

    /// See `KeyedEncodingContainerProtocol`
    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
      let container = UnkeyedContainer(
        codingPath: self.codingPath + [key],
        configuration: self.configuration
      )
      self.childContainers[key.stringValue] = container
      return container
    }

    /// See `KeyedEncodingContainerProtocol`
    func superEncoder() -> Encoder {
      fatalError()
    }

    /// See `KeyedEncodingContainerProtocol`
    func superEncoder(forKey key: Key) -> Encoder {
      fatalError()
    }
  }

  /// Private `UnkeyedEncodingContainer`.
  private final class UnkeyedContainer: UnkeyedEncodingContainer, _Container {
    var codingPath: [CodingKey]
    var count: Int = 0
    var internalData: URLEncodedFormData = []
    var childContainers: [Int: _Container] = [:]
    private let configuration: URLFormEncoder.Configuration

    func getData() throws -> URLEncodedFormData {
      var result = self.internalData
      for (key, childContainer) in self.childContainers {
        result.children[String(key)] = try childContainer.getData()
      }
      switch self.configuration.arrayEncoding {
      case .separator(let arraySeparator):
        var valuesToImplode = result.values
        result.values = []
        if
          case .bracket = self.configuration.arrayEncoding,
          let emptyStringChild = self.internalData.children[""]
        {
          valuesToImplode = valuesToImplode + emptyStringChild.values
          result.children[""]?.values = []
        }
        let implodedValue = try valuesToImplode.map({ (value: URLQueryFragment) -> String in
          return try value.asUrlEncoded()
        }).joined(separator: String(arraySeparator))
        result.values = [.urlEncoded(implodedValue)]
      case .bracket, .values:
        break
      }
      return result
    }

    init(
      codingPath: [CodingKey],
      configuration: URLFormEncoder.Configuration
    ) {
      self.codingPath = codingPath
      self.configuration = configuration
    }

    func encodeNil() throws {
      // skip
    }

    func encode<T>(_ value: T) throws where T: Encodable {
      defer { self.count += 1 }
      if let convertible = value as? URLQueryFragmentConvertible {
        let value = convertible.urlQueryFragmentValue
        switch self.configuration.arrayEncoding {
        case .bracket:
          var emptyStringChild = self.internalData.children[""] ?? []
          emptyStringChild.values.append(value)
          self.internalData.children[""] = emptyStringChild
        case .separator, .values:
          self.internalData.values.append(value)
        }
      } else {
        let encoder = _Encoder(codingPath: codingPath, configuration: configuration)
        try value.encode(to: encoder)
        let childData = try encoder.getData()
        if childData.hasOnlyValues {
          switch self.configuration.arrayEncoding {
          case .bracket:
            var emptyStringChild = self.internalData.children[""] ?? []
            emptyStringChild.values.append(contentsOf: childData.values)
            self.internalData.children[""] = emptyStringChild
          case .separator, .values:
            self.internalData.values.append(contentsOf: childData.values)
          }
        } else {
          self.internalData.children[count.description] = try encoder.getData()
        }
      }
    }

    /// See UnkeyedEncodingContainer.nestedContainer
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey>
    where NestedKey: CodingKey
    {
      defer { count += 1 }
      let container = KeyedContainer<NestedKey>(
        codingPath: self.codingPath,
        configuration: self.configuration
      )
      self.childContainers[self.count] = container
      return .init(container)
    }

    /// See UnkeyedEncodingContainer.nestedUnkeyedContainer
    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
      defer { count += 1 }
      let container = UnkeyedContainer(
        codingPath: self.codingPath,
        configuration: self.configuration
      )
      self.childContainers[count] = container
      return container
    }

    /// See UnkeyedEncodingContainer.superEncoder
    func superEncoder() -> Encoder {
      fatalError()
    }
  }

  /// Private `SingleValueEncodingContainer`.
  private final class SingleValueContainer: SingleValueEncodingContainer, _Container {
    /// See `SingleValueEncodingContainer`
    var codingPath: [CodingKey]

    func getData() throws -> URLEncodedFormData {
      return data
    }

    /// The data being encoded
    var data: URLEncodedFormData = []

    private let configuration: URLFormEncoder.Configuration

    /// Creates a new single value encoder
    init(
      codingPath: [CodingKey],
      configuration: URLFormEncoder.Configuration
    ) {
      self.codingPath = codingPath
      self.configuration = configuration
    }

    /// See `SingleValueEncodingContainer`
    func encodeNil() throws {
      // skip
    }

    /// See `SingleValueEncodingContainer`
    func encode<T>(_ value: T) throws where T: Encodable {
      if let convertible = value as? URLQueryFragmentConvertible {
        self.data.values.append(convertible.urlQueryFragmentValue)
      } else {
        let encoder = _Encoder(codingPath: self.codingPath, configuration: self.configuration)
        try value.encode(to: encoder)
        self.data = try encoder.getData()
      }
    }
  }
}

private extension EncodingError {
  static func invalidValue(_ value: Any, at path: [CodingKey]) -> EncodingError {
    let pathString = path.map { $0.stringValue }.joined(separator: ".")
    let context = EncodingError.Context(
      codingPath: path,
      debugDescription: "Invalid value at '\(pathString)': \(value)"
    )
    return Swift.EncodingError.invalidValue(value, context)
  }
}

struct URLEncodedFormSerializer {
  let splitVariablesOn: Character
  let splitKeyValueOn: Character

  /// Create a new form-urlencoded data parser.
  init(splitVariablesOn: Character = "&", splitKeyValueOn: Character = "=") {
    self.splitVariablesOn = splitVariablesOn
    self.splitKeyValueOn = splitKeyValueOn
  }

  func serialize(_ data: URLEncodedFormData, codingPath: [CodingKey] = []) throws -> String {
    var entries: [String] = []
    let key = try codingPath.toURLEncodedKey()
    for value in data.values {
      if codingPath.count == 0 {
        try entries.append(value.asUrlEncoded())
      } else {
        try entries.append(key + String(splitKeyValueOn) + value.asUrlEncoded())
      }
    }
    for (key, child) in data.children {
      entries.append(try serialize(child, codingPath: codingPath + [_CodingKey(stringValue: key) as CodingKey]))
    }
    return entries.joined(separator: String(splitVariablesOn))
  }

  struct _CodingKey: CodingKey {
    var stringValue: String

    init(stringValue: String) {
      self.stringValue = stringValue
    }

    var intValue: Int?

    init?(intValue: Int) {
      self.intValue = intValue
      self.stringValue = intValue.description
    }
  }
}

extension Array where Element == CodingKey {
  func toURLEncodedKey() throws -> String {
    if count < 1 {
      return ""
    }
    return try self[0].stringValue.urlEncoded(codingPath: self) + self[1...].map({ (key: CodingKey) -> String in
      return try "[" + key.stringValue.urlEncoded(codingPath: self) + "]"
    }).joined()
  }
}

// MARK: Utilties
extension String {
  /// Prepares a `String` for inclusion in form-urlencoded data.
  func urlEncoded(codingPath: [CodingKey] = []) throws -> String {
    guard let result = self.addingPercentEncoding(
      withAllowedCharacters: _allowedCharacters
    ) else {
      throw EncodingError.invalidValue(self, EncodingError.Context(
        codingPath: codingPath,
        debugDescription: "Unable to add percent encoding to \(self)"
      ))
    }
    return result
  }
}

/// Characters allowed in form-urlencoded data.
private var _allowedCharacters: CharacterSet = {
  var allowed = CharacterSet.urlQueryAllowed
  // these symbols are reserved for url-encoded form
  allowed.remove(charactersIn: "?&=[];+")
  return allowed
}()

enum URLQueryFragment: ExpressibleByStringLiteral, Equatable {
  init(stringLiteral: String) {
    self = .urlDecoded(stringLiteral)
  }

  case urlEncoded(String)
  case urlDecoded(String)

  /// Returns the URL Encoded version
  func asUrlEncoded() throws -> String {
    switch self {
    case .urlEncoded(let encoded):
      return encoded
    case .urlDecoded(let decoded):
      return try decoded.urlEncoded()
    }
  }

  /// Returns the URL Decoded version
  func asUrlDecoded() throws -> String {
    switch self {
    case .urlEncoded(let encoded):
      guard let decoded = encoded.removingPercentEncoding else {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Unable to remove percent encoding for \(encoded)"))
      }
      return decoded
    case .urlDecoded(let decoded):
      return decoded
    }
  }

  /// Do comparison and hashing using the decoded version as there are multiple ways something can be encoded.
  /// Certain characters that are not typically encoded could have been encoded making string comparisons between two encodings not work
  static func == (lhs: URLQueryFragment, rhs: URLQueryFragment) -> Bool {
    do {
      return try lhs.asUrlDecoded() == rhs.asUrlDecoded()
    } catch {
      return false
    }
  }

  func hash(into: inout Hasher) {
    do {
      try self.asUrlDecoded().hash(into: &into)
    } catch {
      print("Error hashing: \(error)")
    }
  }
}

/// Represents application/x-www-form-urlencoded encoded data.
internal struct URLEncodedFormData: ExpressibleByArrayLiteral, ExpressibleByStringLiteral, ExpressibleByDictionaryLiteral, Equatable {
  var values: [URLQueryFragment]
  var children: [String: URLEncodedFormData]

  var hasOnlyValues: Bool {
    return children.count == 0
  }

  var allChildKeysAreSequentialIntegers: Bool {
    for i in 0...children.count-1 {
      if !children.keys.contains(String(i)) {
        return false
      }
    }
    return true
  }

  init(values: [URLQueryFragment] = [], children: [String: URLEncodedFormData] = [:]) {
    self.values = values
    self.children = children
  }

  init(stringLiteral: String) {
    self.values = [.urlDecoded(stringLiteral)]
    self.children = [:]
  }

  init(arrayLiteral: String...) {
    self.values = arrayLiteral.map({ (s: String) -> URLQueryFragment in
      return .urlDecoded(s)
    })
    self.children = [:]
  }

  init(dictionaryLiteral: (String, URLEncodedFormData)...) {
    self.values = []
    self.children = Dictionary(uniqueKeysWithValues: dictionaryLiteral)
  }

  mutating func set(value: URLQueryFragment, forPath path: [String]) {
    guard let firstElement = path.first else {
      self.values.append(value)
      return
    }
    var child: URLEncodedFormData
    if let existingChild = self.children[firstElement] {
      child = existingChild
    } else {
      child = []
    }
    child.set(value: value, forPath: Array(path[1...]))
    self.children[firstElement] = child
  }
}

/// Capable of converting to / from `URLQueryFragment`.
protocol URLQueryFragmentConvertible {
  /// Converts `URLQueryFragment` to self.
  init?(urlQueryFragmentValue value: URLQueryFragment)

  /// Converts self to `URLQueryFragment`.
  var urlQueryFragmentValue: URLQueryFragment { get }
}

extension String: URLQueryFragmentConvertible {
  init?(urlQueryFragmentValue value: URLQueryFragment) {
    guard let result = try? value.asUrlDecoded() else {
      return nil
    }
    self = result
  }

  var urlQueryFragmentValue: URLQueryFragment {
    return .urlDecoded(self)
  }
}

extension FixedWidthInteger {
  /// `URLEncodedFormDataConvertible` conformance.
  init?(urlQueryFragmentValue value: URLQueryFragment) {
    guard let decodedString = try? value.asUrlDecoded(),
          let fwi = Self.init(decodedString) else {
      return nil
    }
    self = fwi
  }

  /// `URLEncodedFormDataConvertible` conformance.
  var urlQueryFragmentValue: URLQueryFragment {
    return .urlDecoded(self.description)
  }
}

extension Int: URLQueryFragmentConvertible { }
extension Int8: URLQueryFragmentConvertible { }
extension Int16: URLQueryFragmentConvertible { }
extension Int32: URLQueryFragmentConvertible { }
extension Int64: URLQueryFragmentConvertible { }
extension UInt: URLQueryFragmentConvertible { }
extension UInt8: URLQueryFragmentConvertible { }
extension UInt16: URLQueryFragmentConvertible { }
extension UInt32: URLQueryFragmentConvertible { }
extension UInt64: URLQueryFragmentConvertible { }


extension BinaryFloatingPoint {
  /// `URLEncodedFormDataConvertible` conformance.
  init?(urlQueryFragmentValue value: URLQueryFragment) {
    guard let decodedString = try? value.asUrlDecoded(),
          let double = Double(decodedString) else {
      return nil
    }
    self = Self.init(double)
  }

  /// `URLEncodedFormDataConvertible` conformance.
  var urlQueryFragmentValue: URLQueryFragment {
    return .urlDecoded(Double(self).description)
  }
}

extension Float: URLQueryFragmentConvertible { }
extension Double: URLQueryFragmentConvertible { }

extension Bool: URLQueryFragmentConvertible {
  /// `URLEncodedFormDataConvertible` conformance.
  init?(urlQueryFragmentValue value: URLQueryFragment) {
    guard let decodedString = try? value.asUrlDecoded() else {
      return nil
    }
    switch decodedString.lowercased() {
    case "1", "true": self = true
    case "0", "false": self = false
    default: return nil
    }
  }

  /// `URLEncodedFormDataConvertible` conformance.
  var urlQueryFragmentValue: URLQueryFragment {
    return .urlDecoded(self.description)
  }
}

extension Decimal: URLQueryFragmentConvertible {
  /// `URLEncodedFormDataConvertible` conformance.
  init?(urlQueryFragmentValue value: URLQueryFragment) {
    guard let decodedString = try? value.asUrlDecoded(),
          let decimal = Decimal(string: decodedString) else {
      return nil
    }
    self = decimal
  }

  /// `URLEncodedFormDataConvertible` conformance.
  var urlQueryFragmentValue: URLQueryFragment {
    return .urlDecoded(self.description)
  }
}

extension Date: URLQueryFragmentConvertible {
  init?(urlQueryFragmentValue value: URLQueryFragment) {
    guard let double = Double(urlQueryFragmentValue: value) else {
      return nil
    }
    self = Date(timeIntervalSince1970: double)
  }

  var urlQueryFragmentValue: URLQueryFragment {
    return timeIntervalSince1970.urlQueryFragmentValue
  }
}

extension URL: URLQueryFragmentConvertible {
  init?(urlQueryFragmentValue value: URLQueryFragment) {
    guard let string = String(urlQueryFragmentValue: value) else {
      return nil
    }
    self.init(string: string)
  }

  var urlQueryFragmentValue: URLQueryFragment {
    self.absoluteString.urlQueryFragmentValue
  }
}

extension ISO8601DateFormatter {
  static var threadSpecific: ISO8601DateFormatter {
    ISO8601DateFormatter()
  }
}
