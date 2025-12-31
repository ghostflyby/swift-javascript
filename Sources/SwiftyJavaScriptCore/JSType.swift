import JavaScriptCore

public enum JSType {
  case undefined
  case null
  case boolean
  case number
  case string
  case symbol
  case object
  case bigInt
}

@available(macOS 15.0, *)
extension JSType {
  init(_ rawValue: JavaScriptCore.JSType) {
    switch rawValue {
    case kJSTypeUndefined:
      self = .undefined
    case kJSTypeNull:
      self = .null
    case kJSTypeBoolean:
      self = .boolean
    case kJSTypeNumber:
      self = .number
    case kJSTypeString:
      self = .string
    case kJSTypeSymbol:
      self = .symbol
    case kJSTypeObject:
      self = .object
    case kJSTypeBigInt:
      self = .bigInt
    default:
      fatalError("Unknown JSType raw value: \(rawValue)")
    }
  }

  var rawValue: JavaScriptCore.JSType {
    switch self {
    case .undefined:
      return kJSTypeUndefined
    case .null:
      return kJSTypeNull
    case .boolean:
      return kJSTypeBoolean
    case .number:
      return kJSTypeNumber
    case .string:
      return kJSTypeString
    case .symbol:
      return kJSTypeSymbol
    case .object:
      return kJSTypeObject
    case .bigInt:
      return kJSTypeBigInt
    }
  }
}
