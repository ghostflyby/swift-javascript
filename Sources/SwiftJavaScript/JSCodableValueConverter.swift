import Foundation

private indirect enum JSCodableNode {
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

    if let bool = object as? Bool {
      return .bool(bool)
    }

    if let number = object as? NSNumber {
      if CFGetTypeID(number) == CFBooleanGetTypeID() {
        return .bool(number.boolValue)
      }
      return .number(number.doubleValue)
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

public enum JSCodableValueConverter<T: Codable>: JSValueConverter {
  public typealias SwiftType = T

  public static func decode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> T {
    do {
      return try tryDecode(value, in: context)
    } catch {
      fatalError("JSCodableValueConverter.decode failed: \(error)")
    }
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> T {
    let node = try nodeFromJSValue(value, in: context)
    let jsonObject = node.jsonObject()

    let data: Data
    do {
      data = try JSONSerialization.data(
        withJSONObject: jsonObject,
        options: [.fragmentsAllowed]
      )
    } catch {
      throw .codable("decode JSON serialization failed: \(error)")
    }

    do {
      return try JSONDecoder().decode(T.self, from: data)
    } catch {
      throw .codable("decode failed: \(error)")
    }
  }

  @_lifetime(borrow context)
  public static func encode<E: JSEngine>(
    _ value: T,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    do {
      return try tryEncode(value, in: context)
    } catch {
      return context.makeUndefined()
    }
  }

  @_lifetime(borrow context)
  public static func tryEncode<E: JSEngine>(
    _ value: T,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    let data: Data
    do {
      data = try JSONEncoder().encode(value)
    } catch {
      throw .codable("encode failed: \(error)")
    }

    let jsonObject: Any
    do {
      jsonObject = try JSONSerialization.jsonObject(
        with: data,
        options: [.fragmentsAllowed]
      )
    } catch {
      throw .codable("encode JSON parsing failed: \(error)")
    }

    let node = try JSCodableNode.fromJSONObject(jsonObject)
    return try jsValueFromNode(node, in: context)
  }

  fileprivate static func nodeFromJSValue<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSCodableNode {
    if value.isUndefined(in: context) || value.isNull(in: context) {
      return .null
    }

    if value.isBoolean(in: context) {
      return .bool(value.toBool(in: context))
    }

    if value.isNumber(in: context) {
      return .number(value.toDouble(in: context))
    }

    if value.isString(in: context) {
      return .string(value.toString(in: context))
    }

    if value.isObject(in: context) {
      let valueHandle = value.borrowHandle()

      if E.isArrayHandle(valueHandle, in: context.driverContextHandle) == true {
        let lengthValue = try readStringProperty("length", on: valueHandle, in: context)
        if lengthValue.isUndefined(in: context) {
          throw .codable("array length missing")
        }

        let lengthNumber = lengthValue.toDouble(in: context)
        if !lengthNumber.isFinite {
          throw .codable("array length conversion failed")
        }

        let count = max(0, Int(lengthNumber))
        var nodes: [JSCodableNode] = []
        nodes.reserveCapacity(count)

        for index in 0..<count {
          let element = try readIndexProperty(UInt32(index), on: valueHandle, in: context)
          nodes.append(try nodeFromJSValue(element, in: context))
        }

        return .array(nodes)
      }

      let names = E.propertyNamesForHandle(on: valueHandle, in: context.driverContextHandle) ?? []
      var object: [String: JSCodableNode] = [:]
      object.reserveCapacity(names.count)

      for key in names {
        let property = try readStringProperty(key, on: valueHandle, in: context)
        object[key] = try nodeFromJSValue(property, in: context)
      }

      return .object(object)
    }

    throw .typeMismatch(expected: "codable compatible JSValue", actual: value.type(in: context))
  }

  @_lifetime(borrow context)
  fileprivate static func jsValueFromNode<E: JSEngine>(
    _ node: JSCodableNode,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    switch node {
    case .null:
      return context.makeNull()

    case .bool(let value):
      return context.makeBoolean(value)

    case .number(let value):
      return context.makeNumber(value)

    case .string(let value):
      return context.makeString(value)

    case .array(let array):
      let arrayValue = context.makeArray()
      for (index, item) in array.enumerated() {
        let encoded = try jsValueFromNode(item, in: context)
        guard
          E.setIndexPropertyHandle(
            at: UInt32(index),
            on: arrayValue.borrowHandle(),
            to: encoded.borrowHandle(),
            in: context.driverContextHandle
          )
        else {
          throw .codable("array element write failed at index \(index)")
        }
      }
      return arrayValue

    case .object(let object):
      let objectValue = context.makeObject()
      for (key, value) in object {
        let encoded = try jsValueFromNode(value, in: context)
        guard
          E.setStringPropertyHandle(
            key,
            on: objectValue.borrowHandle(),
            to: encoded.borrowHandle(),
            in: context.driverContextHandle,
            attributes: .none
          )
        else {
          throw .codable("object property write failed for key \(key)")
        }
      }
      return objectValue
    }
  }

  @_lifetime(borrow context)
  private static func readStringProperty<E: JSEngine>(
    _ key: String,
    on object: JSValueHandle<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getStringPropertyHandle(
        key,
        on: object,
        in: context.driverContextHandle
      )
    )

    switch consume result {
    case .value(let value):
      return value
    case .exception:
      throw .codable("object property read failed for key \(key)")
    }
  }

  @_lifetime(borrow context)
  private static func readIndexProperty<E: JSEngine>(
    _ index: UInt32,
    on object: JSValueHandle<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    let result: JSResult<JSValue<E>> = bridgeHandleResult(
      E.getIndexPropertyHandle(
        at: index,
        on: object,
        in: context.driverContextHandle
      )
    )

    switch consume result {
    case .value(let value):
      return value
    case .exception:
      throw .codable("array element read failed at index \(index)")
    }
  }
}
