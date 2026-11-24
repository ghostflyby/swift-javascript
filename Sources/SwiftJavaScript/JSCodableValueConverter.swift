import Foundation

indirect enum JSCodableNode {
  case object([String: JSCodableNode])
  case array([JSCodableNode])
  case string(String)
  case number(Double)
  case bool(Bool)
  case null

  func jsonObject() -> Any {
    switch self {
    case .object(let object):
      return object.mapValues { $0.jsonObject() }
    case .array(let array):
      return array.map { $0.jsonObject() }
    case .string(let value):
      return value
    case .number(let value):
      return value
    case .bool(let value):
      return value
    case .null:
      return NSNull()
    }
  }

  static func fromJSONObject(_ object: Any) throws(JSValueConversionError) -> JSCodableNode {
    if object is NSNull {
      return .null
    }

    // Numbers must be classified before `Bool`: `NSNumber` bridges to `Bool`
    // for 0/1, so an early `as? Bool` check would turn the JSON number `1`
    // into `true` (and make `[Int]` round-trips decode as bools).
    if let number = object as? NSNumber {
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        return .bool(number.boolValue)
      }
      return .number(number.doubleValue)
    }

    if let bool = object as? Bool {
      return .bool(bool)
    }

    if let string = object as? String {
      return .string(string)
    }

    if let array = object as? [Any] {
      var mapped: [JSCodableNode] = []
      mapped.reserveCapacity(array.count)
      for item in array {
        mapped.append(try fromJSONObject(item))
      }
      return .array(mapped)
    }

    if let object = object as? [String: Any] {
      var mapped: [String: JSCodableNode] = [:]
      mapped.reserveCapacity(object.count)
      for (key, value) in object {
        mapped[key] = try fromJSONObject(value)
      }
      return .object(mapped)
    }

    throw .codable("unsupported JSON fragment: \(type(of: object))")
  }
}

/// A `Codable` ⇄ JavaScript converter. The surface conformances
/// (`JSValueDecoder`/`JSValueEncoder`) live in
/// `JSCodableValueConverterSurface.swift`; `JSCodableNode` is the shared
/// intermediate tree.
public enum JSCodableValueConverter<T: Codable> {
  public typealias SwiftType = T
}
