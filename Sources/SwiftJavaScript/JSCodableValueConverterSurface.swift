import Foundation

// MARK: - `JSCodableValueConverter` over the surface scopes
//
// This extension walks the engine's local value view through any
// `JSInstantContext` window: every property read is adopted by the window's
// arena (one track per result), every created value is promoted with
// `persist`, and object/array assembly uses the driver's string-key and index
// writers. `JSCodableNode` is the shared intermediate tree.

extension JSCodableValueConverter: JSValueDecoder, JSValueEncoder {
  public static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> T {
    do {
      return try tryDecode(value, in: context)
    } catch {
      fatalError("JSCodableValueConverter.decode failed: \(error)")
    }
  }

  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> T {
    let node = try nodeFromSurfaceValue(value, in: context)

    let data: Data
    do {
      data = try JSONSerialization.data(
        withJSONObject: node.jsonObject(),
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

  public static func encode<C: JSValueScope & ~Copyable>(
    _ value: T,
    in context: borrowing C
  ) -> C.Value {
    do {
      return try tryEncode(value, in: context)
    } catch {
      return context.persist(context.makeUndefined())
    }
  }

  public static func tryEncode<C: JSValueScope & ~Copyable>(
    _ value: T,
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value {
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
    return try jsValueFromSurfaceNode(node, in: context)
  }

  // MARK: - Value to node

  private static func nodeFromSurfaceValue<C: JSValueScope & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> JSCodableNode {
    if value.isUndefined() || value.isNull() {
      return .null
    }

    if value.isBoolean() {
      return .bool(value.toBoolean())
    }

    if value.isNumber() {
      return .number(value.toNumber())
    }

    if value.isString() {
      return .string(value.toString())
    }

    if value.isObject() {
      let valueHandle = value.borrowHandle()
      let driver = context.driverContextHandle

      if driver.isArrayHandle(valueHandle) == true {
        let lengthValue = try readSurfaceStringProperty(
          "length",
          on: valueHandle,
          in: context
        )
        if lengthValue.isUndefined() {
          throw .codable("array length missing")
        }

        let lengthNumber = lengthValue.toNumber()
        if !lengthNumber.isFinite {
          throw .codable("array length conversion failed")
        }

        let count = max(0, Int(lengthNumber))
        var nodes: [JSCodableNode] = []
        nodes.reserveCapacity(count)

        for index in 0..<count {
          let element = try readSurfaceIndexProperty(
            UInt32(index),
            on: valueHandle,
            in: context
          )
          nodes.append(try nodeFromSurfaceValue(element, in: context))
        }

        return .array(nodes)
      }

      let names = driver.propertyNamesForHandle(on: valueHandle) ?? []
      var object: [String: JSCodableNode] = [:]
      object.reserveCapacity(names.count)

      for key in names {
        let property = try readSurfaceStringProperty(key, on: valueHandle, in: context)
        object[key] = try nodeFromSurfaceValue(property, in: context)
      }

      return .object(object)
    }

    throw .typeMismatch(
      expected: "codable compatible JSValue",
      actual: value.type()
    )
  }

  // MARK: - Node to value

  private static func jsValueFromSurfaceNode<C: JSValueScope & ~Copyable>(
    _ node: JSCodableNode,
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value {
    switch node {
    case .null:
      return context.persist(context.makeNull())

    case .bool(let value):
      return context.persist(context.makeBoolean(value))

    case .number(let value):
      return context.persist(context.makeNumber(value))

    case .string(let value):
      return context.persist(context.makeString(value))

    case .array(let array):
      guard case .value(let arrayCallback) = context.makeArray() else {
        throw .codable("array creation failed")
      }
      let arrayValue = context.persist(arrayCallback)
      for (index, item) in array.enumerated() {
        let encoded = try jsValueFromSurfaceNode(item, in: context)
        guard
          context.driverContextHandle.setIndexPropertyHandle(
            at: UInt32(index),
            on: arrayValue.borrowHandle(),
            to: encoded.borrowHandle()
          )
        else {
          throw .codable("array element write failed at index \(index)")
        }
      }
      return arrayValue

    case .object(let object):
      guard case .value(let objectCallback) = context.makeObject() else {
        throw .codable("object creation failed")
      }
      let objectValue = context.persist(objectCallback)
      for (key, value) in object {
        let encoded = try jsValueFromSurfaceNode(value, in: context)
        let propertyStringKey = context.makePropertyStringKey(key)
        guard
          context.driverContextHandle.setPropertyStringKeyHandle(
            propertyStringKey.borrowHandle(in: context.driverContextHandle),
            on: objectValue.borrowHandle(),
            to: encoded.borrowHandle(),
            attributes: .none
          )
        else {
          throw .codable("object property write failed for key \(key)")
        }
      }
      return objectValue
    }
  }

  // MARK: - Property reads

  private static func readSurfaceStringProperty<C: JSValueScope & ~Copyable>(
    _ key: String,
    on object: C.ContextHandle.ValueHandle,
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value {
    guard
      let keyHandle = context.driverContextHandle.makePropertyStringKeyHandle(key)
    else {
      throw .codable("property key creation failed for key \(key)")
    }
    defer { _ = keyHandle.releaseReference() }

    let result: JSResult<C.Value> = bridgeSurfaceHandleResult(
      context.driverContextHandle.getPropertyStringKeyHandle(keyHandle, on: object),
      in: context
    )

    switch consume result {
    case .value(let value):
      return value
    case .exception:
      throw .codable("object property read failed for key \(key)")
    }
  }

  private static func readSurfaceIndexProperty<C: JSValueScope & ~Copyable>(
    _ index: UInt32,
    on object: C.ContextHandle.ValueHandle,
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value {
    let result: JSResult<C.Value> = bridgeSurfaceHandleResult(
      context.driverContextHandle.getIndexPropertyHandle(at: index, on: object),
      in: context
    )

    switch consume result {
    case .value(let value):
      return value
    case .exception:
      throw .codable("array element read failed at index \(index)")
    }
  }
}
