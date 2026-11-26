import Foundation

// MARK: - `JSCodableValueConverter` over the surface scopes
//
// This extension walks the engine's local value view through any
// `JSInstantContext` window using only value-level requirements: `isArray`,
// `propertyNames`, the string-key/index readers and writers, `persist` and
// `withInstantWindow`. Every property read is adopted by the window's arena
// (one track per result), every created value is promoted with `persist`, and
// object/array assembly runs inside the window opened by `withInstantWindow`.
// `JSCodableNode` is the shared intermediate tree.

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
    let node = try context.withInstantWindow {
      window throws(JSValueConversionError) in
      try nodeFromSurfaceValue(C.self, value, in: window)
    }

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
    return try context.withInstantWindow {
      window throws(JSValueConversionError) in
      try jsValueFromSurfaceNode(node, in: context, window: window)
    }
  }

  // MARK: - Value to node

  private static func nodeFromSurfaceValue<C: JSInstantContext & ~Copyable>(
    _ contextType: C.Type,
    _ value: borrowing C.Value,
    in window: borrowing C.Context.InstantContext
  ) throws(JSValueConversionError) -> JSCodableNode {
    _ = contextType
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
      if value.isArray(in: window) {
        let lengthValue = try readSurfaceStringProperty(
          C.self,
          "length",
          on: value,
          in: window
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
            C.self,
            index,
            on: value,
            in: window
          )
          nodes.append(try nodeFromSurfaceValue(C.self, element, in: window))
        }

        return .array(nodes)
      }

      let names = value.propertyNames(in: window)
      var object: [String: JSCodableNode] = [:]
      object.reserveCapacity(names.count)

      for key in names {
        let property = try readSurfaceStringProperty(
          C.self,
          key,
          on: value,
          in: window
        )
        object[key] = try nodeFromSurfaceValue(C.self, property, in: window)
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
    in context: borrowing C,
    window: borrowing C.Context.InstantContext
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
        let encoded = try jsValueFromSurfaceNode(
          item,
          in: context,
          window: window
        )
        guard arrayValue.setProperty(at: index, to: encoded, in: window) else {
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
        let encoded = try jsValueFromSurfaceNode(
          value,
          in: context,
          window: window
        )
        let propertyStringKey = window.makePropertyStringKey(key)
        guard
          objectValue.setProperty(
            propertyStringKey,
            to: encoded,
            attributes: .none,
            in: window
          )
        else {
          throw .codable("object property write failed for key \(key)")
        }
      }
      return objectValue
    }
  }

  // MARK: - Property reads

  private static func readSurfaceStringProperty<C: JSInstantContext & ~Copyable>(
    _ contextType: C.Type,
    _ key: String,
    on object: borrowing C.Value,
    in window: borrowing C.Context.InstantContext
  ) throws(JSValueConversionError) -> C.Value {
    _ = contextType
    let propertyKey = window.makePropertyStringKey(key)
    let result = object.getProperty(propertyKey, in: window)
    switch consume result {
    case .value(let value):
      return value
    case .exception:
      throw .codable("object property read failed for key \(key)")
    }
  }

  private static func readSurfaceIndexProperty<C: JSInstantContext & ~Copyable>(
    _ contextType: C.Type,
    _ index: Int,
    on object: borrowing C.Value,
    in window: borrowing C.Context.InstantContext
  ) throws(JSValueConversionError) -> C.Value {
    _ = contextType
    let result = object.getProperty(at: index, in: window)
    switch consume result {
    case .value(let value):
      return value
    case .exception:
      throw .codable("array element read failed at index \(index)")
    }
  }
}
