final class JSCodableNode {
  enum Kind {
    case object([String: JSCodableNode])
    case array([JSCodableNode])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
  }

  var kind: Kind

  init(_ kind: Kind) {
    self.kind = kind
  }
}

public enum JSCodableValueConverter<T: Codable>: JSValueConverter {
  public typealias SwiftType = T

  public static func decode(_ value: borrowing JSValue, in context: borrowing JSInstantContext)
    -> T
  {
    do {
      return try tryDecode(value, in: context)
    } catch {
      fatalError("JSCodableValueConverter.decode failed: \(error)")
    }
  }

  public static func tryDecode(
    _ value: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) throws(JSValueConversionError) -> T {
    let node = try nodeFromJSValue(value, in: context)
    let decoder = _JSCodableDecoder(root: node, codingPath: [])
    do {
      return try T(from: decoder)
    } catch {
      throw .codable("decode failed: \(error)")
    }
  }

  public static func encode(_ value: T, in context: borrowing JSInstantContext) -> JSValue {
    do {
      return try tryEncode(value, in: context)
    } catch {
      return JSValue(undefinedIn: context)
    }
  }

  public static func tryEncode(
    _ value: T,
    in context: borrowing JSInstantContext
  ) throws(JSValueConversionError) -> JSValue {
    let encoder = _JSCodableEncoder(context: context, codingPath: [])
    do {
      try value.encode(to: encoder)
      if let ref = encoder.result {
        return JSValue(ref: ref, ctx: context)
      }
      return JSValue(undefinedIn: context)
    } catch {
      throw .codable("encode failed: \(error)")
    }
  }

  static func nodeFromJSValue(
    _ value: borrowing JSValue,
    in context: borrowing JSInstantContext
  ) throws(JSValueConversionError) -> JSCodableNode {
    if value.isUndefined(in: context) || value.isNull(in: context) {
      return JSCodableNode(.null)
    }
    if value.isBoolean(in: context) {
      return JSCodableNode(.bool(value.toBool(in: context)))
    }
    if value.isNumber(in: context) {
      return JSCodableNode(.number(value.toDouble(in: context)))
    }
    if value.isString(in: context) {
      return JSCodableNode(.string(value.toString(in: context)))
    }
    if value.isObject(in: context) {
      if value.isArray(in: context) {
        let count: Int
        switch JSResult.from(
          handleResult: JavaScriptCoreBackendDriver.getStringPropertyHandle(
            "length",
            on: value.valueHandle(in: context),
            in: context.driverContextHandle
          ))
        {
        case .exception:
          throw .codable("array length read raised exception")
        case .value(let lengthValue):
          if lengthValue.isUndefined(in: context) {
            throw .codable("array length missing")
          }
          let lengthNumber = lengthValue.toDouble(in: context)
          if !lengthNumber.isFinite {
            throw .codable("array length conversion failed")
          }
          count = max(0, Int(lengthNumber))
        }

        var nodes: [JSCodableNode] = []
        nodes.reserveCapacity(count)
        for index in 0..<count {
          switch JSResult.from(
            handleResult: JavaScriptCoreBackendDriver.getIndexPropertyHandle(
              at: UInt32(index),
              on: value.valueHandle(in: context),
              in: context.driverContextHandle
            ))
          {
          case .exception:
            throw .codable("array element read failed at index \(index)")
          case .value(let element):
            nodes.append(try nodeFromJSValue(element, in: context))
          }
        }
        return JSCodableNode(.array(nodes))
      }
      var object: [String: JSCodableNode] = [:]
      let names =
        JavaScriptCoreBackendDriver.propertyNamesForHandle(
          on: value.valueHandle(in: context),
          in: context.driverContextHandle
        ) ?? []
      object.reserveCapacity(names.count)

      for key in names {
        switch JSResult.from(
          handleResult: JavaScriptCoreBackendDriver.getStringPropertyHandle(
            key,
            on: value.valueHandle(in: context),
            in: context.driverContextHandle
          ))
        {
        case .exception:
          throw .codable("object property read failed for key \(key)")
        case .value(let property):
          object[key] = try nodeFromJSValue(property, in: context)
        }
      }
      return JSCodableNode(.object(object))
    }

    throw .typeMismatch(expected: "codable compatible JSValue", actual: value.type(in: context))
  }

  static func jsValueFromNode(
    _ node: JSCodableNode,
    in context: borrowing JSInstantContext
  ) throws(JSValueConversionError) -> JSValue {
    switch node.kind {
    case .null:
      return JSValue(nullIn: context)
    case .bool(let value):
      return JSValue(boolean: value, in: context)
    case .number(let value):
      return JSValue(number: value, in: context)
    case .string(let value):
      return JSValue(string: value, in: context)
    case .array(let array):
      let arrayValue = try makeDriverArrayValue(in: context)
      for (index, item) in array.enumerated() {
        let encoded = try jsValueFromNode(item, in: context)
        guard
          JavaScriptCoreBackendDriver.setIndexPropertyHandle(
            at: UInt32(index),
            on: arrayValue.valueHandle(in: context),
            to: encoded.valueHandle(in: context),
            in: context.driverContextHandle
          )
        else {
          throw .codable("array element write failed at index \(index)")
        }
      }
      return arrayValue
    case .object(let object):
      let objectValue = try makeDriverObjectValue(in: context)
      for (key, value) in object {
        let encoded = try jsValueFromNode(value, in: context)
        guard
          JavaScriptCoreBackendDriver.setStringPropertyHandle(
            key,
            on: objectValue.valueHandle(in: context),
            to: encoded.valueHandle(in: context),
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
}

private func makeDriverObjectValue(in context: borrowing JSInstantContext)
  throws(JSValueConversionError)
  -> JSValue
{
  switch JSResult.from(
    handleResult: JavaScriptCoreBackendDriver.makeObjectResultHandle(context.driverContextHandle))
  {
  case .exception:
    throw .codable("object creation raised exception")
  case .value(let object):
    return object
  }
}

private func makeDriverArrayValue(in context: borrowing JSInstantContext)
  throws(JSValueConversionError)
  -> JSValue
{
  switch JSResult.from(
    handleResult: JavaScriptCoreBackendDriver.makeArrayResultHandle(context.driverContextHandle))
  {
  case .exception:
    throw .codable("array creation failed")
  case .value(let array):
    return array
  }
}

private func makeDriverObjectRef(in globalContextRef: JavaScriptCoreGlobalContextRef)
  -> JavaScriptCoreObjectRef
{
  let context = JSInstantContext(ctx: globalContextRef)
  do {
    return try makeDriverObjectValue(in: context).ref
  } catch {
    preconditionFailure("JSCodable object creation raised exception")
  }
}

private func makeDriverArrayRef(in globalContextRef: JavaScriptCoreGlobalContextRef)
  -> JavaScriptCoreObjectRef
{
  let context = JSInstantContext(ctx: globalContextRef)
  do {
    return try makeDriverArrayValue(in: context).ref
  } catch {
    preconditionFailure("JSCodable array creation raised exception")
  }
}

final class _JSCodableEncoder: Encoder {
  let globalContextRef: JavaScriptCoreGlobalContextRef
  var codingPath: [any CodingKey]
  var userInfo: [CodingUserInfoKey: Any] = [:]
  var result: JavaScriptCoreValueRef?
  private let onCommit: ((JavaScriptCoreValueRef) -> Void)?

  init(
    context: borrowing JSInstantContext,
    codingPath: [any CodingKey],
    onCommit: ((JavaScriptCoreValueRef) -> Void)? = nil
  ) {
    self.globalContextRef = context.globalContextRef
    self.codingPath = codingPath
    self.onCommit = onCommit
  }

  func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
    let objectRef = makeDriverObjectRef(in: globalContextRef)
    commit(objectRef)
    let container = _JSCodableKeyedEncodingContainer<Key>(
      globalContextRef: globalContextRef,
      objectRef: objectRef,
      codingPath: codingPath
    )
    return KeyedEncodingContainer(container)
  }

  func unkeyedContainer() -> any UnkeyedEncodingContainer {
    let arrayRef = makeDriverArrayRef(in: globalContextRef)
    commit(arrayRef)
    return _JSCodableUnkeyedEncodingContainer(
      globalContextRef: globalContextRef,
      arrayRef: arrayRef,
      codingPath: codingPath
    )
  }

  func singleValueContainer() -> any SingleValueEncodingContainer {
    _JSCodableSingleValueEncodingContainer(
      globalContextRef: globalContextRef,
      codingPath: codingPath,
      onCommit: { ref in
        self.commit(ref)
      }
    )
  }

  private func commit(_ ref: JavaScriptCoreValueRef) {
    result = ref
    onCommit?(ref)
  }
}

final class _JSCodableKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
  let globalContextRef: JavaScriptCoreGlobalContextRef
  let objectRef: JavaScriptCoreObjectRef
  var codingPath: [any CodingKey]

  private var instantContext: JSInstantContext { JSInstantContext(ctx: globalContextRef) }
  init(
    globalContextRef: JavaScriptCoreGlobalContextRef,
    objectRef: JavaScriptCoreObjectRef,
    codingPath: [any CodingKey]
  ) {
    self.globalContextRef = globalContextRef
    self.objectRef = objectRef
    self.codingPath = codingPath
  }

  func encodeNil(forKey key: Key) throws {
    let context = instantContext
    set(JSValue(nullIn: context).retainedRef(), forKey: key.stringValue)
  }

  func encode(_ value: Bool, forKey key: Key) throws {
    let context = instantContext
    set(JSValue(boolean: value, in: context).retainedRef(), forKey: key.stringValue)
  }

  func encode(_ value: String, forKey key: Key) throws {
    let context = instantContext
    set(JSValue(string: value, in: context).retainedRef(), forKey: key.stringValue)
  }

  func encode(_ value: Double, forKey key: Key) throws {
    let context = instantContext
    set(JSValue(number: value, in: context).retainedRef(), forKey: key.stringValue)
  }

  func encode(_ value: Float, forKey key: Key) throws {
    try encode(Double(value), forKey: key)
  }
  func encode(_ value: Int, forKey key: Key) throws {
    try encode(Double(value), forKey: key)
  }
  func encode(_ value: Int8, forKey key: Key) throws {
    try encode(Double(value), forKey: key)
  }
  func encode(_ value: Int16, forKey key: Key) throws {
    try encode(Double(value), forKey: key)
  }
  func encode(_ value: Int32, forKey key: Key) throws {
    try encode(Double(value), forKey: key)
  }
  func encode(_ value: Int64, forKey key: Key) throws {
    try encode(Double(value), forKey: key)
  }
  func encode(_ value: UInt, forKey key: Key) throws {
    try encode(Double(value), forKey: key)
  }
  func encode(_ value: UInt8, forKey key: Key) throws {
    try encode(Double(value), forKey: key)
  }
  func encode(_ value: UInt16, forKey key: Key) throws {
    try encode(Double(value), forKey: key)
  }
  func encode(_ value: UInt32, forKey key: Key) throws {
    try encode(Double(value), forKey: key)
  }
  func encode(_ value: UInt64, forKey key: Key) throws {
    try encode(Double(value), forKey: key)
  }

  func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
    let child = _JSCodableEncoder(
      context: instantContext,
      codingPath: codingPath + [key],
      onCommit: { ref in
        self.set(ref, forKey: key.stringValue)
      }
    )
    try value.encode(to: child)
    if child.result == nil {
      let context = instantContext
      set(JSValue(undefinedIn: context).retainedRef(), forKey: key.stringValue)
    }
  }

  func nestedContainer<NestedKey>(
    keyedBy keyType: NestedKey.Type,
    forKey key: Key
  ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
    let childRef = makeDriverObjectRef(in: globalContextRef)
    set(childRef, forKey: key.stringValue)
    let container = _JSCodableKeyedEncodingContainer<NestedKey>(
      globalContextRef: globalContextRef,
      objectRef: childRef,
      codingPath: codingPath + [key]
    )
    return KeyedEncodingContainer(container)
  }

  func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
    let childRef = makeDriverArrayRef(in: globalContextRef)
    set(childRef, forKey: key.stringValue)
    return _JSCodableUnkeyedEncodingContainer(
      globalContextRef: globalContextRef,
      arrayRef: childRef,
      codingPath: codingPath + [key]
    )
  }

  func superEncoder() -> any Encoder {
    _JSCodableEncoder(context: instantContext, codingPath: codingPath)
  }

  func superEncoder(forKey key: Key) -> any Encoder {
    return _JSCodableEncoder(
      context: instantContext,
      codingPath: codingPath + [key],
      onCommit: { ref in
        self.set(ref, forKey: key.stringValue)
      }
    )
  }

  private func set(_ ref: JavaScriptCoreValueRef, forKey key: String) {
    let context = instantContext
    let object = JSValue(ref: objectRef, ctx: context)
    let value = JSValue(ref: ref, ctx: context)
    object.setProperty(value, forKey: JSStringManaged(key), in: context)
  }
}

final class _JSCodableUnkeyedEncodingContainer: UnkeyedEncodingContainer {
  let globalContextRef: JavaScriptCoreGlobalContextRef
  let arrayRef: JavaScriptCoreObjectRef
  var codingPath: [any CodingKey]
  var count: Int = 0

  private var instantContext: JSInstantContext { JSInstantContext(ctx: globalContextRef) }
  init(
    globalContextRef: JavaScriptCoreGlobalContextRef,
    arrayRef: JavaScriptCoreObjectRef,
    codingPath: [any CodingKey]
  ) {
    self.globalContextRef = globalContextRef
    self.arrayRef = arrayRef
    self.codingPath = codingPath
  }

  func encodeNil() throws {
    let context = instantContext
    append(JSValue(nullIn: context).retainedRef())
  }
  func encode(_ value: Bool) throws {
    let context = instantContext
    append(JSValue(boolean: value, in: context).retainedRef())
  }
  func encode(_ value: String) throws {
    let context = instantContext
    append(JSValue(string: value, in: context).retainedRef())
  }
  func encode(_ value: Double) throws {
    let context = instantContext
    append(JSValue(number: value, in: context).retainedRef())
  }
  func encode(_ value: Float) throws { try encode(Double(value)) }
  func encode(_ value: Int) throws { try encode(Double(value)) }
  func encode(_ value: Int8) throws { try encode(Double(value)) }
  func encode(_ value: Int16) throws { try encode(Double(value)) }
  func encode(_ value: Int32) throws { try encode(Double(value)) }
  func encode(_ value: Int64) throws { try encode(Double(value)) }
  func encode(_ value: UInt) throws { try encode(Double(value)) }
  func encode(_ value: UInt8) throws { try encode(Double(value)) }
  func encode(_ value: UInt16) throws { try encode(Double(value)) }
  func encode(_ value: UInt32) throws { try encode(Double(value)) }
  func encode(_ value: UInt64) throws { try encode(Double(value)) }

  func encode<T>(_ value: T) throws where T: Encodable {
    let index = count
    let child = _JSCodableEncoder(
      context: instantContext,
      codingPath: codingPath,
      onCommit: { ref in
        self.appendAtCurrent(ref, index: index)
      }
    )
    try value.encode(to: child)
    if child.result == nil {
      let context = instantContext
      appendAtCurrent(JSValue(undefinedIn: context).retainedRef(), index: index)
    }
    count += 1
  }

  func nestedContainer<NestedKey>(
    keyedBy keyType: NestedKey.Type
  ) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
    let objectRef = makeDriverObjectRef(in: globalContextRef)
    append(objectRef)
    let container = _JSCodableKeyedEncodingContainer<NestedKey>(
      globalContextRef: globalContextRef,
      objectRef: objectRef,
      codingPath: codingPath
    )
    return KeyedEncodingContainer(container)
  }

  func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
    let childRef = makeDriverArrayRef(in: globalContextRef)
    append(childRef)
    return _JSCodableUnkeyedEncodingContainer(
      globalContextRef: globalContextRef, arrayRef: childRef, codingPath: codingPath)
  }

  func superEncoder() -> any Encoder {
    let index = count
    count += 1
    return _JSCodableEncoder(
      context: instantContext,
      codingPath: codingPath,
      onCommit: { ref in
        self.appendAtCurrent(ref, index: index)
      }
    )
  }

  private func append(_ ref: JavaScriptCoreValueRef) {
    appendAtCurrent(ref, index: count)
    count += 1
  }

  private func appendAtCurrent(_ ref: JavaScriptCoreValueRef, index: Int) {
    let context = instantContext
    let array = JSValue(ref: arrayRef, ctx: context)
    let value = JSValue(ref: ref, ctx: context)
    array.setProperty(value, at: UInt32(index), in: context)
  }
}

final class _JSCodableSingleValueEncodingContainer: SingleValueEncodingContainer {
  let globalContextRef: JavaScriptCoreGlobalContextRef
  var codingPath: [any CodingKey]
  let onCommit: (JavaScriptCoreValueRef) -> Void

  private var instantContext: JSInstantContext { JSInstantContext(ctx: globalContextRef) }
  init(
    globalContextRef: JavaScriptCoreGlobalContextRef,
    codingPath: [any CodingKey],
    onCommit: @escaping (JavaScriptCoreValueRef) -> Void
  ) {
    self.globalContextRef = globalContextRef
    self.codingPath = codingPath
    self.onCommit = onCommit
  }

  func encodeNil() throws {
    let context = instantContext
    onCommit(JSValue(nullIn: context).retainedRef())
  }
  func encode(_ value: Bool) throws {
    let context = instantContext
    onCommit(JSValue(boolean: value, in: context).retainedRef())
  }
  func encode(_ value: String) throws {
    let context = instantContext
    onCommit(JSValue(string: value, in: context).retainedRef())
  }
  func encode(_ value: Double) throws {
    let context = instantContext
    onCommit(JSValue(number: value, in: context).retainedRef())
  }
  func encode(_ value: Float) throws { try encode(Double(value)) }
  func encode(_ value: Int) throws { try encode(Double(value)) }
  func encode(_ value: Int8) throws { try encode(Double(value)) }
  func encode(_ value: Int16) throws { try encode(Double(value)) }
  func encode(_ value: Int32) throws { try encode(Double(value)) }
  func encode(_ value: Int64) throws { try encode(Double(value)) }
  func encode(_ value: UInt) throws { try encode(Double(value)) }
  func encode(_ value: UInt8) throws { try encode(Double(value)) }
  func encode(_ value: UInt16) throws { try encode(Double(value)) }
  func encode(_ value: UInt32) throws { try encode(Double(value)) }
  func encode(_ value: UInt64) throws { try encode(Double(value)) }

  func encode<T>(_ value: T) throws where T: Encodable {
    let child = _JSCodableEncoder(
      context: instantContext,
      codingPath: codingPath,
      onCommit: onCommit
    )
    try value.encode(to: child)
    if child.result == nil {
      let context = instantContext
      onCommit(JSValue(undefinedIn: context).retainedRef())
    }
  }
}

final class _JSCodableDecoder: Decoder {
  let root: JSCodableNode
  var codingPath: [any CodingKey]
  var userInfo: [CodingUserInfoKey: Any] = [:]

  init(root: JSCodableNode, codingPath: [any CodingKey]) {
    self.root = root
    self.codingPath = codingPath
  }

  func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
  where Key: CodingKey {
    guard case .object(let object) = root.kind else {
      throw DecodingError.typeMismatch(
        [String: JSCodableNode].self,
        .init(codingPath: codingPath, debugDescription: "Expected object"))
    }
    let container = _JSCodableKeyedDecodingContainer<Key>(object: object, codingPath: codingPath)
    return KeyedDecodingContainer(container)
  }

  func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
    guard case .array(let array) = root.kind else {
      throw DecodingError.typeMismatch(
        [JSCodableNode].self, .init(codingPath: codingPath, debugDescription: "Expected array"))
    }
    return _JSCodableUnkeyedDecodingContainer(array: array, codingPath: codingPath)
  }

  func singleValueContainer() throws -> any SingleValueDecodingContainer {
    _JSCodableSingleValueDecodingContainer(node: root, codingPath: codingPath)
  }
}

struct _JSCodableKeyedDecodingContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
  let object: [String: JSCodableNode]
  var codingPath: [any CodingKey]

  var allKeys: [Key] {
    object.keys.compactMap { Key(stringValue: $0) }
  }

  func contains(_ key: Key) -> Bool {
    object[key.stringValue] != nil
  }

  func decodeNil(forKey key: Key) throws -> Bool {
    guard let node = object[key.stringValue] else { return true }
    if case .null = node.kind { return true }
    return false
  }

  func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
    try single(forKey: key).decode(Bool.self)
  }
  func decode(_ type: String.Type, forKey key: Key) throws -> String {
    try single(forKey: key).decode(String.self)
  }
  func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
    try single(forKey: key).decode(Double.self)
  }
  func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
    try single(forKey: key).decode(Float.self)
  }
  func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
    try single(forKey: key).decode(Int.self)
  }
  func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
    try single(forKey: key).decode(Int8.self)
  }
  func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
    try single(forKey: key).decode(Int16.self)
  }
  func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
    try single(forKey: key).decode(Int32.self)
  }
  func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
    try single(forKey: key).decode(Int64.self)
  }
  func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
    try single(forKey: key).decode(UInt.self)
  }
  func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
    try single(forKey: key).decode(UInt8.self)
  }
  func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
    try single(forKey: key).decode(UInt16.self)
  }
  func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
    try single(forKey: key).decode(UInt32.self)
  }
  func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
    try single(forKey: key).decode(UInt64.self)
  }

  func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T: Decodable {
    let decoder = try nestedDecoder(forKey: key)
    return try T(from: decoder)
  }

  func nestedContainer<NestedKey>(
    keyedBy keyType: NestedKey.Type,
    forKey key: Key
  ) throws -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
    let decoder = try nestedDecoder(forKey: key)
    return try decoder.container(keyedBy: keyType)
  }

  func nestedUnkeyedContainer(forKey key: Key) throws -> any UnkeyedDecodingContainer {
    let decoder = try nestedDecoder(forKey: key)
    return try decoder.unkeyedContainer()
  }

  func superDecoder() throws -> any Decoder {
    _JSCodableDecoder(root: JSCodableNode(.object(object)), codingPath: codingPath)
  }

  func superDecoder(forKey key: Key) throws -> any Decoder {
    try nestedDecoder(forKey: key)
  }

  private func nestedDecoder(forKey key: Key) throws -> _JSCodableDecoder {
    guard let node = object[key.stringValue] else {
      throw DecodingError.keyNotFound(
        key, .init(codingPath: codingPath, debugDescription: "Missing key \(key.stringValue)"))
    }
    return _JSCodableDecoder(root: node, codingPath: codingPath + [key])
  }

  private func single(forKey key: Key) throws -> _JSCodableSingleValueDecodingContainer {
    let decoder = try nestedDecoder(forKey: key)
    return _JSCodableSingleValueDecodingContainer(
      node: decoder.root, codingPath: decoder.codingPath)
  }
}

struct _JSCodableUnkeyedDecodingContainer: UnkeyedDecodingContainer {
  let array: [JSCodableNode]
  var codingPath: [any CodingKey]
  var currentIndex: Int = 0

  var count: Int? { array.count }
  var isAtEnd: Bool { currentIndex >= array.count }

  mutating func decodeNil() throws -> Bool {
    guard !isAtEnd else {
      throw DecodingError.valueNotFound(
        Any?.self,
        .init(codingPath: codingPath, debugDescription: "Unkeyed container out of bounds"))
    }
    if case .null = array[currentIndex].kind {
      currentIndex += 1
      return true
    }
    return false
  }

  mutating func decode(_ type: Bool.Type) throws -> Bool { try decodeSingle(Bool.self) }
  mutating func decode(_ type: String.Type) throws -> String { try decodeSingle(String.self) }
  mutating func decode(_ type: Double.Type) throws -> Double { try decodeSingle(Double.self) }
  mutating func decode(_ type: Float.Type) throws -> Float { try decodeSingle(Float.self) }
  mutating func decode(_ type: Int.Type) throws -> Int { try decodeSingle(Int.self) }
  mutating func decode(_ type: Int8.Type) throws -> Int8 { try decodeSingle(Int8.self) }
  mutating func decode(_ type: Int16.Type) throws -> Int16 { try decodeSingle(Int16.self) }
  mutating func decode(_ type: Int32.Type) throws -> Int32 { try decodeSingle(Int32.self) }
  mutating func decode(_ type: Int64.Type) throws -> Int64 { try decodeSingle(Int64.self) }
  mutating func decode(_ type: UInt.Type) throws -> UInt { try decodeSingle(UInt.self) }
  mutating func decode(_ type: UInt8.Type) throws -> UInt8 { try decodeSingle(UInt8.self) }
  mutating func decode(_ type: UInt16.Type) throws -> UInt16 { try decodeSingle(UInt16.self) }
  mutating func decode(_ type: UInt32.Type) throws -> UInt32 { try decodeSingle(UInt32.self) }
  mutating func decode(_ type: UInt64.Type) throws -> UInt64 { try decodeSingle(UInt64.self) }

  mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
    guard !isAtEnd else {
      throw DecodingError.valueNotFound(
        T.self, .init(codingPath: codingPath, debugDescription: "Unkeyed container out of bounds"))
    }
    let node = array[currentIndex]
    currentIndex += 1
    let decoder = _JSCodableDecoder(root: node, codingPath: codingPath)
    return try T(from: decoder)
  }

  mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) throws
    -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey
  {
    guard !isAtEnd else {
      throw DecodingError.valueNotFound(
        [String: Any].self,
        .init(codingPath: codingPath, debugDescription: "Unkeyed container out of bounds"))
    }
    let node = array[currentIndex]
    currentIndex += 1
    let decoder = _JSCodableDecoder(root: node, codingPath: codingPath)
    return try decoder.container(keyedBy: keyType)
  }

  mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer {
    guard !isAtEnd else {
      throw DecodingError.valueNotFound(
        [Any].self,
        .init(codingPath: codingPath, debugDescription: "Unkeyed container out of bounds"))
    }
    let node = array[currentIndex]
    currentIndex += 1
    let decoder = _JSCodableDecoder(root: node, codingPath: codingPath)
    return try decoder.unkeyedContainer()
  }

  mutating func superDecoder() throws -> any Decoder {
    guard !isAtEnd else {
      throw DecodingError.valueNotFound(
        Decoder.self,
        .init(codingPath: codingPath, debugDescription: "Unkeyed container out of bounds"))
    }
    let node = array[currentIndex]
    currentIndex += 1
    return _JSCodableDecoder(root: node, codingPath: codingPath)
  }

  private mutating func decodeSingle<T>(_ type: T.Type) throws -> T where T: Decodable {
    guard !isAtEnd else {
      throw DecodingError.valueNotFound(
        T.self, .init(codingPath: codingPath, debugDescription: "Unkeyed container out of bounds"))
    }
    let node = array[currentIndex]
    currentIndex += 1
    let container = _JSCodableSingleValueDecodingContainer(node: node, codingPath: codingPath)
    return try container.decode(T.self)
  }
}

struct _JSCodableSingleValueDecodingContainer: SingleValueDecodingContainer {
  let node: JSCodableNode
  var codingPath: [any CodingKey]

  func decodeNil() -> Bool {
    if case .null = node.kind { return true }
    return false
  }

  func decode(_ type: Bool.Type) throws -> Bool {
    guard case .bool(let value) = node.kind else {
      throw DecodingError.typeMismatch(
        Bool.self, .init(codingPath: codingPath, debugDescription: "Expected Bool"))
    }
    return value
  }

  func decode(_ type: String.Type) throws -> String {
    guard case .string(let value) = node.kind else {
      throw DecodingError.typeMismatch(
        String.self, .init(codingPath: codingPath, debugDescription: "Expected String"))
    }
    return value
  }

  func decode(_ type: Double.Type) throws -> Double {
    guard case .number(let value) = node.kind else {
      throw DecodingError.typeMismatch(
        Double.self, .init(codingPath: codingPath, debugDescription: "Expected Number"))
    }
    return value
  }

  func decode(_ type: Float.Type) throws -> Float { Float(try decode(Double.self)) }

  func decode(_ type: Int.Type) throws -> Int { try integer(Int.self) }
  func decode(_ type: Int8.Type) throws -> Int8 { try integer(Int8.self) }
  func decode(_ type: Int16.Type) throws -> Int16 { try integer(Int16.self) }
  func decode(_ type: Int32.Type) throws -> Int32 { try integer(Int32.self) }
  func decode(_ type: Int64.Type) throws -> Int64 { try integer(Int64.self) }
  func decode(_ type: UInt.Type) throws -> UInt { try integer(UInt.self) }
  func decode(_ type: UInt8.Type) throws -> UInt8 { try integer(UInt8.self) }
  func decode(_ type: UInt16.Type) throws -> UInt16 { try integer(UInt16.self) }
  func decode(_ type: UInt32.Type) throws -> UInt32 { try integer(UInt32.self) }
  func decode(_ type: UInt64.Type) throws -> UInt64 { try integer(UInt64.self) }

  func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
    let decoder = _JSCodableDecoder(root: node, codingPath: codingPath)
    return try T(from: decoder)
  }

  private func integer<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
    let value = try decode(Double.self)
    guard value.isFinite, value.rounded(.towardZero) == value else {
      throw DecodingError.typeMismatch(
        type, .init(codingPath: codingPath, debugDescription: "Expected integer number"))
    }
    guard let typed = T(exactly: value) else {
      throw DecodingError.typeMismatch(
        type, .init(codingPath: codingPath, debugDescription: "Integer out of range"))
    }
    return typed
  }
}
