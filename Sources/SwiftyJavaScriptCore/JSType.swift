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

extension JSValue {
  public var type: JSType {
    JSType(JSValueGetType(ctx, ref))
  }
}

extension JSValue {
  public var isUndefined: Bool {
    JSValueIsUndefined(ctx, ref)
  }

  public var isNull: Bool {
    JSValueIsNull(ctx, ref)
  }

  public var isBoolean: Bool {
    JSValueIsBoolean(ctx, ref)
  }

  public var isNumber: Bool {
    JSValueIsNumber(ctx, ref)
  }

  public var isString: Bool {
    JSValueIsString(ctx, ref)
  }

  public var isSymbol: Bool {
    JSValueIsSymbol(ctx, ref)
  }

  public var isObject: Bool {
    JSValueIsObject(ctx, ref)
  }

  public var isBigInt: Bool {
    JSValueIsBigInt(ctx, ref)
  }
}
