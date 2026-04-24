import Foundation
import SwiftJavaScript

package struct MockRuntime: Sendable, Equatable {
  package let id: String

  package init(id: String) {
    self.id = id
  }
}

package struct MockRuntimeHandle: JSRuntimeManualReferenceCountedHandle, @unchecked Sendable {
  package let rawRuntime: MockRuntime

  package init(rawRuntime: MockRuntime) {
    self.rawRuntime = rawRuntime
  }

  package var engineType: MockEngine.Type {
    MockEngine.self
  }

  package func retainReference() -> Bool { true }
  package func releaseReference() -> Bool { true }
}

package struct MockContext: Sendable, Equatable {
  package let runtimeID: String

  package init(runtimeID: String) {
    self.runtimeID = runtimeID
  }
}

package struct MockContextHandle: JSContextManualReferenceCountedHandle, @unchecked Sendable {
  package let rawContext: MockContext

  package init(rawContext: MockContext) {
    self.rawContext = rawContext
  }

  package func bindContextOwner<E>(_ owner: SwiftJavaScript.JSContext<E>)
  where MockContextHandle == E.ContextHandle, E: SwiftJavaScript.JSEngine {
    _ = owner
  }

  package var engineType: MockEngine.Type {
    MockEngine.self
  }

  package func retainReference() -> Bool { true }
  package func releaseReference() -> Bool { true }
}

package struct MockValue: Sendable, Equatable {
  package let kind: String
  package let payload: String

  package init(kind: String, payload: String) {
    self.kind = kind
    self.payload = payload
  }
}

private final class MockValueHandleStorage: @unchecked Sendable {
  let rawValue: MockValue

  init(rawValue: MockValue) {
    self.rawValue = rawValue
  }
}

package struct MockClass: Sendable, Equatable, Hashable {
  package let id: String

  package init(id: String) {
    self.id = id
  }
}

package struct MockClassHandle: JSClassManualReferenceCountedHandle, @unchecked Sendable,
  Equatable, Hashable
{
  package let rawClass: MockClass

  package init(rawClass: MockClass) {
    self.rawClass = rawClass
  }

  package func retainReference() -> Bool { true }
  package func releaseReference() -> Bool { true }
}

package final class MockStringHandle: JSStringManualReferenceCountedHandle, @unchecked Sendable {
  private let count: Int
  private let storage: UnsafeMutablePointer<UInt16>

  package init(_ value: String) {
    let units = Array(value.utf16)
    count = units.count
    storage = .allocate(capacity: max(1, count))
    if count > 0 {
      storage.initialize(from: units, count: count)
    }
  }

  deinit {
    if count > 0 {
      storage.deinitialize(count: count)
    }
    storage.deallocate()
  }

  package var length: Int { count }

  package var characters: UnsafePointer<UInt16> {
    UnsafePointer(storage)
  }

  package var string: String {
    String(decoding: UnsafeBufferPointer(start: characters, count: count), as: UTF16.self)
  }

  @discardableResult
  package func retainReference() -> Bool { true }

  @discardableResult
  package func releaseReference() -> Bool { true }
}

package struct MockValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {
  package typealias Engine = MockEngine
  package typealias RawValue = MockValue

  private let storagePointer: UnsafeMutableRawPointer

  package var rawValue: MockValue {
    Unmanaged<MockValueHandleStorage>.fromOpaque(storagePointer).takeUnretainedValue().rawValue
  }

  package init(rawValue: MockValue) {
    self.storagePointer = Unmanaged.passRetained(
      MockValueHandleStorage(rawValue: rawValue)
    ).toOpaque()
  }

  package var storageWords: JSValueStorageWords {
    (
      word0: UInt64(UInt(bitPattern: storagePointer)),
      word1: 0,
      word2: 0
    )
  }

  package init(storageWords: JSValueStorageWords) {
    self.storagePointer = UnsafeMutableRawPointer(bitPattern: UInt(storageWords.word0))!
  }

  package var engineType: MockEngine.Type {
    MockEngine.self
  }

  package func retainReference() -> Bool {
    let storage = Unmanaged<MockValueHandleStorage>.fromOpaque(storagePointer).takeUnretainedValue()
    _ = Unmanaged.passRetained(storage)
    return true
  }

  package func releaseReference() -> Bool {
    _ = Unmanaged<MockValueHandleStorage>.fromOpaque(storagePointer).takeRetainedValue()
    return true
  }
}

package enum MockEngine: JSEngine {
  package typealias RuntimeHandle = MockRuntimeHandle
  package typealias ContextHandle = MockContextHandle
  package typealias ValueHandle = MockValueHandle
  package typealias ClassHandle = MockClassHandle
  package typealias StringHandle = MockStringHandle

  package static func stringLength(_ stringHandle: MockStringHandle) -> Int {
    stringHandle.length
  }

  package static func stringCharacters(_ stringHandle: MockStringHandle) -> UnsafePointer<UInt16>? {
    stringHandle.characters
  }

  package static func makeJSString(_ value: String) -> MockStringHandle {
    MockStringHandle(value)
  }

  package static func stringEquals(_ lhs: MockStringHandle, _ rhs: MockStringHandle) -> Bool {
    lhs.string == rhs.string
  }
}

package enum MockDriver: JSEngine {
  package typealias ValueHandle = MockValueHandle
  package typealias ClassHandle = MockClassHandle
  package typealias Engine = MockEngine
  package typealias RuntimeHandle = MockRuntimeHandle
  package typealias ContextHandle = MockContextHandle
  package typealias StringHandle = MockStringHandle

  package static let capabilities = JSEngineCapabilities(supportsHostObjects: true)

  package static func makeRuntime() -> MockRuntime {
    MockRuntime(id: "runtime")
  }

  package static func makeContext(in runtime: MockRuntime) -> MockContext {
    MockContext(runtimeID: runtime.id)
  }

  @_lifetime(immortal)
  package static func evaluateScript(
    _ script: String,
    in context: MockContext,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<MockValue> {
    _ = sourceURL
    _ = startingLineNumber
    if script == "throw" {
      return .exception(MockValue(kind: "exception", payload: "\(context.runtimeID):throw"))
    }
    return .value(MockValue(kind: "script", payload: "\(context.runtimeID):\(script)"))
  }

  package static func makeString(_ value: String, in context: MockContext) -> MockValue {
    MockValue(kind: "string", payload: "\(context.runtimeID):\(value)")
  }

  package static func makeSymbol(_ value: String, in context: MockContext) -> MockValue {
    MockValue(kind: "symbol", payload: "\(context.runtimeID):\(value)")
  }

  package static func makeNumber(_ value: Double, in context: MockContext) -> MockValue {
    MockValue(kind: "number", payload: "\(context.runtimeID):\(value)")
  }

  package static func makeBoolean(_ value: Bool, in context: MockContext) -> MockValue {
    MockValue(kind: "boolean", payload: "\(context.runtimeID):\(value)")
  }

  package static func makeNull(in context: MockContext) -> MockValue {
    MockValue(kind: "null", payload: context.runtimeID)
  }

  package static func makeUndefined(in context: MockContext) -> MockValue {
    MockValue(kind: "undefined", payload: context.runtimeID)
  }

  @_lifetime(immortal)
  package static func makeObject(in context: MockContext) -> JSResult<MockValue> {
    .value(MockValue(kind: "object", payload: context.runtimeID))
  }

  @_lifetime(immortal)
  package static func makeArray(in context: MockContext) -> JSResult<MockValue> {
    .value(MockValue(kind: "array", payload: context.runtimeID))
  }

  package static func propertyNames(on object: MockValue, in context: MockContext) -> [String] {
    [context.runtimeID, object.kind, object.payload]
  }

  @_lifetime(immortal)
  package static func getProperty(_ key: String, on object: MockValue, in context: MockContext)
    -> JSResult<MockValue>
  {
    .value(MockValue(kind: "property", payload: "\(context.runtimeID):\(object.payload):\(key)"))
  }

  @_lifetime(immortal)
  package static func getProperty(_ key: MockValue, on object: MockValue, in context: MockContext)
    -> JSResult<MockValue>
  {
    .value(
      MockValue(kind: "property", payload: "\(context.runtimeID):\(object.payload):\(key.payload)"))
  }

  @_lifetime(immortal)
  package static func getProperty(
    at index: UInt32,
    on object: MockValue,
    in context: MockContext
  ) -> JSResult<MockValue> {
    .value(MockValue(kind: "index", payload: "\(context.runtimeID):\(object.payload):\(index)"))
  }

  package static func hasProperty(_ key: String, on object: MockValue, in context: MockContext)
    -> Bool
  {
    _ = context
    return object.payload.contains(key)
  }

  package static func hasProperty(_ key: MockValue, on object: MockValue, in context: MockContext)
    -> Bool
  {
    _ = context
    return object.payload.contains(key.payload)
  }

  @_lifetime(immortal)
  package static func deleteProperty(_ key: String, on object: MockValue, in context: MockContext)
    -> JSResult<Void>
  {
    _ = key
    _ = object
    _ = context
    return .value(())
  }

  @_lifetime(immortal)
  package static func deleteProperty(
    _ key: MockValue,
    on object: MockValue,
    in context: MockContext
  ) -> JSResult<Void> {
    _ = key
    _ = object
    _ = context
    return .value(())
  }

  @_lifetime(immortal)
  package static func callFunction(
    _ function: MockValue,
    this thisValue: MockValue?,
    arguments: [MockValue],
    in context: MockContext
  ) -> JSResult<MockValue> {
    _ = thisValue
    return .value(
      MockValue(
        kind: "call",
        payload: "\(context.runtimeID):\(function.payload):\(arguments.count)"
      )
    )
  }

  @_lifetime(immortal)
  package static func construct(
    _ constructor: MockValue,
    arguments: [MockValue],
    in context: MockContext
  ) -> JSResult<MockValue> {
    _ = constructor
    return .value(MockValue(kind: "construct", payload: "\(context.runtimeID):\(arguments.count)"))
  }

  @_lifetime(immortal)
  package static func toObject(_ value: MockValue, in context: MockContext) -> JSResult<MockValue> {
    _ = context
    return .value(MockValue(kind: "object", payload: value.payload))
  }

  package static func isArray(_ value: MockValue, in context: MockContext) -> Bool {
    _ = context
    return value.kind == "array"
  }

  package static func isDate(_ value: MockValue, in context: MockContext) -> Bool {
    _ = context
    return value.kind == "date"
  }

  package static func isInstanceOf(
    _ value: MockValue,
    constructor: MockValue,
    in context: MockContext
  ) -> Bool {
    _ = context
    return value.payload == constructor.payload
  }

  package static func looselyEquals(
    _ lhs: MockValue,
    _ rhs: MockValue,
    in context: MockContext
  ) -> Bool {
    _ = context
    if lhs.kind == rhs.kind {
      return lhs.payload == rhs.payload
    }
    if lhs.kind == "number" && rhs.kind == "string" {
      return lhs.payload == rhs.payload
    }
    if lhs.kind == "string" && rhs.kind == "number" {
      return lhs.payload == rhs.payload
    }
    return false
  }

  package static func strictlyEquals(
    _ lhs: MockValue,
    _ rhs: MockValue,
    in context: MockContext
  ) -> Bool {
    _ = context
    return lhs == rhs
  }

  @_lifetime(immortal)
  package static func setProperty(
    _ key: String,
    on object: MockValue,
    to value: MockValue,
    in context: MockContext,
    attributes: JSHostMemberAttributes
  ) -> JSResult<Void> {
    _ = key
    _ = object
    _ = value
    _ = context
    _ = attributes
    return .value(())
  }

  @_lifetime(immortal)
  package static func setProperty(
    _ key: MockValue,
    on object: MockValue,
    to value: MockValue,
    in context: MockContext,
    attributes: JSHostMemberAttributes
  ) -> JSResult<Void> {
    _ = key
    _ = object
    _ = value
    _ = context
    _ = attributes
    return .value(())
  }

  @_lifetime(immortal)
  package static func setProperty(
    at index: UInt32,
    on object: MockValue,
    to value: MockValue,
    in context: MockContext
  ) -> JSResult<Void> {
    _ = index
    _ = object
    _ = value
    _ = context
    return .value(())
  }

  package static func stringLength(_ stringHandle: MockStringHandle) -> Int {
    stringHandle.length
  }

  package static func stringCharacters(_ stringHandle: MockStringHandle) -> UnsafePointer<UInt16>? {
    stringHandle.characters
  }

  package static func makeJSString(_ value: String) -> MockStringHandle {
    MockStringHandle(value)
  }

  package static func stringEquals(_ lhs: MockStringHandle, _ rhs: MockStringHandle) -> Bool {
    lhs.string == rhs.string
  }
}

extension MockDriver {
  @_lifetime(immortal)
  fileprivate static func resultHandle(from result: consuming JSResult<MockValue>)
    -> JSResult<JSValueHandle<MockEngine>>
  {
    switch consume result {
    case .value(let value):
      return .value(JSValueHandle<MockEngine>(rawValue: value))
    case .exception(let exception):
      return .exception(JSValueHandle<MockEngine>(rawValue: exception))
    }
  }

  package static func makeRuntimeHandle() -> MockRuntimeHandle {
    MockRuntimeHandle(rawRuntime: makeRuntime())
  }

  package static func makeBorrowedContextHandleFromRuntime(
    in runtime: MockRuntimeHandle
  ) -> MockContextHandle? {
    MockContextHandle(rawContext: makeContext(in: runtime.rawRuntime))
  }

  package static func globalObjectValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    JSValueHandle<MockEngine>(
      rawValue: MockValue(kind: "object", payload: "\(context.rawContext.runtimeID):global"))
  }

  package static func makeFunctionValueHandle(
    named name: String,
    callback:
      @escaping (
        _ context: borrowing JSInstantContext<MockEngine>,
        _ this: borrowing JSValue<MockEngine>,
        _ arguments: borrowing JSArguments<MockEngine>
      ) -> (isException: Bool, handle: JSValueHandle<MockEngine>),
    in context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    _ = callback
    return JSValueHandle<MockEngine>(
      rawValue: MockValue(kind: "function", payload: "\(context.rawContext.runtimeID):\(name)"))
  }

  package static func makeStringValueHandle(
    _ value: String,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    JSValueHandle<MockEngine>(rawValue: makeString(value, in: context.rawContext))
  }

  package static func makeNumberValueHandle(
    _ value: Double,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    JSValueHandle<MockEngine>(rawValue: makeNumber(value, in: context.rawContext))
  }

  package static func makeSymbolValueHandle(
    _ value: String,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    JSValueHandle<MockEngine>(rawValue: makeSymbol(value, in: context.rawContext))
  }

  package static func makeNullValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    JSValueHandle<MockEngine>(rawValue: makeNull(in: context.rawContext))
  }

  package static func makeUndefinedValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    JSValueHandle<MockEngine>(rawValue: makeUndefined(in: context.rawContext))
  }

  @_lifetime(immortal)
  package static func makeObjectResultHandle(
    _ context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    resultHandle(from: makeObject(in: context.rawContext))
  }

  @_lifetime(immortal)
  package static func makeArrayResultHandle(
    _ context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    resultHandle(from: makeArray(in: context.rawContext))
  }

  @_lifetime(immortal)
  package static func evaluateScriptResultHandle(
    _ script: String,
    _ context: MockContextHandle,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    resultHandle(
      from: evaluateScript(
        script,
        in: context.rawContext,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    )
  }

  package static func valueTypeForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSType? {
    _ = context
    switch value.rawValue.kind {
    case "undefined":
      return .undefined
    case "null":
      return .null
    case "boolean":
      return .boolean
    case "number":
      return .number
    case "string":
      return .string
    case "symbol":
      return .symbol
    case "object", "array", "call", "construct", "property", "index":
      return .object
    default:
      return nil
    }
  }

  package static func toBooleanForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    _ = context
    return !value.rawValue.payload.isEmpty
  }

  package static func toNumberForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Double {
    _ = context
    return Double(value.rawValue.payload) ?? .nan
  }

  package static func toStringForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> String? {
    _ = context
    return value.rawValue.payload
  }

  package static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    JSValueHandle<MockEngine>(rawValue: makeBoolean(value, in: context.rawContext))
  }

  package static func propertyNamesForHandle(
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> [String]? {
    propertyNames(on: object.rawValue, in: context.rawContext)
  }

  @_lifetime(immortal)
  package static func getStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    resultHandle(from: getProperty(key, on: object.rawValue, in: context.rawContext))
  }

  package static func setStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    switch setProperty(
      key,
      on: object.rawValue,
      to: value.rawValue,
      in: context.rawContext,
      attributes: attributes
    ) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  @_lifetime(immortal)
  package static func getValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    resultHandle(from: getProperty(key.rawValue, on: object.rawValue, in: context.rawContext))
  }

  @_lifetime(immortal)
  package static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    resultHandle(from: getProperty(at: index, on: object.rawValue, in: context.rawContext))
  }

  package static func setValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    switch setProperty(
      key.rawValue,
      on: object.rawValue,
      to: value.rawValue,
      in: context.rawContext,
      attributes: attributes
    ) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func setIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    switch setProperty(at: index, on: object.rawValue, to: value.rawValue, in: context.rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func hasStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    hasProperty(key, on: object.rawValue, in: context.rawContext)
  }

  package static func hasValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    hasProperty(key.rawValue, on: object.rawValue, in: context.rawContext)
  }

  package static func deleteStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    switch deleteProperty(key, on: object.rawValue, in: context.rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func deleteValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    switch deleteProperty(key.rawValue, on: object.rawValue, in: context.rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  @_lifetime(immortal)
  package static func callFunctionHandle(
    _ function: JSValueHandle<MockEngine>,
    this thisValue: JSValueHandle<MockEngine>? = nil,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    resultHandle(
      from: callFunction(
        function.rawValue,
        this: thisValue?.rawValue,
        arguments: arguments.map(\.rawValue),
        in: context.rawContext
      )
    )
  }

  @_lifetime(immortal)
  package static func constructHandle(
    _ constructor: JSValueHandle<MockEngine>,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    resultHandle(
      from: construct(
        constructor.rawValue, arguments: arguments.map(\.rawValue), in: context.rawContext)
    )
  }

  @_lifetime(immortal)
  package static func toObjectHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    resultHandle(from: toObject(value.rawValue, in: context.rawContext))
  }

  package static func isArrayHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    isArray(value.rawValue, in: context.rawContext)
  }

  package static func isDateHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    isDate(value.rawValue, in: context.rawContext)
  }

  package static func isInstanceOfHandle(
    _ value: JSValueHandle<MockEngine>,
    constructor: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    isInstanceOf(value.rawValue, constructor: constructor.rawValue, in: context.rawContext)
  }

  package static func looselyEqualsHandle(
    _ lhs: JSValueHandle<MockEngine>,
    _ rhs: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    looselyEquals(lhs.rawValue, rhs.rawValue, in: context.rawContext)
  }

  package static func strictlyEqualsHandle(
    _ lhs: JSValueHandle<MockEngine>,
    _ rhs: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    strictlyEquals(lhs.rawValue, rhs.rawValue, in: context.rawContext)
  }

  package static func makeArrayBufferWithBytesNoCopyHandle(
    in context: MockContextHandle,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = bytes
    _ = byteLength
    _ = bytesDeallocator
    _ = deallocatorContext
    return nil
  }

  package static func arrayBufferByteLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  package static func arrayBufferBytesPtrForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    _ = value
    _ = context
    return (nil, false)
  }

  package static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    length: Int
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = length
    return nil
  }

  package static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<MockEngine>
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = arrayBuffer
    return nil
  }

  package static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<MockEngine>,
    byteOffset: Int,
    length: Int
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = arrayBuffer
    _ = byteOffset
    _ = length
    return nil
  }

  package static func typedArrayLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  package static func typedArrayByteLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  package static func typedArrayByteOffsetForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  package static func typedArrayBufferForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    _ = value
    _ = context
    return nil
  }

  package static func typedArrayBytesPtrForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    _ = value
    _ = context
    return (nil, false)
  }

  package static func isArrayBufferHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    _ = value
    _ = context
    return false
  }

  package static func typedArrayKindForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSTypedArrayKind? {
    _ = value
    _ = context
    return nil
  }
}

extension MockEngine {
  package static var capabilities: JSEngineCapabilities {
    MockDriver.capabilities
  }

  package static func makeRuntimeHandle() -> MockRuntimeHandle {
    MockDriver.makeRuntimeHandle()
  }

  package static func makeBorrowedContextHandleFromRuntime(
    in runtime: MockRuntimeHandle
  ) -> MockContextHandle? {
    MockDriver.makeBorrowedContextHandleFromRuntime(in: runtime)
  }

  package static func globalObjectValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.globalObjectValueHandle(context)
  }

  package static func makeFunctionValueHandle(
    named name: String,
    callback:
      @escaping (
        _ context: borrowing JSInstantContext<MockEngine>,
        _ this: borrowing JSValue<MockEngine>,
        _ arguments: borrowing JSArguments<MockEngine>
      ) -> (isException: Bool, handle: JSValueHandle<MockEngine>),
    in context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeFunctionValueHandle(named: name, callback: callback, in: context)
  }

  @_lifetime(immortal)
  package static func evaluateScriptResultHandle(
    _ script: String,
    _ context: MockContextHandle,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.evaluateScriptResultHandle(
      script,
      context,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }

  package static func valueTypeForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSType? {
    MockDriver.valueTypeForHandle(value, in: context)
  }

  package static func toBooleanForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.toBooleanForHandle(value, in: context)
  }

  package static func toNumberForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Double {
    MockDriver.toNumberForHandle(value, in: context)
  }

  package static func toStringForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> String? {
    MockDriver.toStringForHandle(value, in: context)
  }

  package static func makeStringValueHandle(
    _ value: String,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeStringValueHandle(value, context)
  }

  package static func makeSymbolValueHandle(
    _ value: String,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeSymbolValueHandle(value, context)
  }

  package static func makeNumberValueHandle(
    _ value: Double,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeNumberValueHandle(value, context)
  }

  package static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeBooleanValueHandle(value, context)
  }

  package static func makeNullValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeNullValueHandle(context)
  }

  package static func makeUndefinedValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeUndefinedValueHandle(context)
  }

  @_lifetime(immortal)
  package static func makeObjectResultHandle(
    _ context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.makeObjectResultHandle(context)
  }

  @_lifetime(immortal)
  package static func makeArrayResultHandle(
    _ context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.makeArrayResultHandle(context)
  }

  package static func propertyNamesForHandle(
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> [String]? {
    MockDriver.propertyNamesForHandle(on: object, in: context)
  }

  @_lifetime(immortal)
  package static func getStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.getStringPropertyHandle(key, on: object, in: context)
  }

  package static func setStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    MockDriver.setStringPropertyHandle(
      key,
      on: object,
      to: value,
      in: context,
      attributes: attributes
    )
  }

  @_lifetime(immortal)
  package static func getValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.getValuePropertyHandle(key, on: object, in: context)
  }

  @_lifetime(immortal)
  package static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.getIndexPropertyHandle(at: index, on: object, in: context)
  }

  package static func setValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    MockDriver.setValuePropertyHandle(
      key,
      on: object,
      to: value,
      in: context,
      attributes: attributes
    )
  }

  package static func setIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.setIndexPropertyHandle(at: index, on: object, to: value, in: context)
  }

  package static func hasStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.hasStringPropertyHandle(key, on: object, in: context)
  }

  package static func hasValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.hasValuePropertyHandle(key, on: object, in: context)
  }

  package static func deleteStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.deleteStringPropertyHandle(key, on: object, in: context)
  }

  package static func deleteValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.deleteValuePropertyHandle(key, on: object, in: context)
  }

  @_lifetime(immortal)
  package static func callFunctionHandle(
    _ function: JSValueHandle<MockEngine>,
    this thisValue: JSValueHandle<MockEngine>? = nil,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.callFunctionHandle(function, this: thisValue, arguments: arguments, in: context)
  }

  @_lifetime(immortal)
  package static func constructHandle(
    _ constructor: JSValueHandle<MockEngine>,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.constructHandle(constructor, arguments: arguments, in: context)
  }

  @_lifetime(immortal)
  package static func toObjectHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.toObjectHandle(value, in: context)
  }

  package static func isArrayHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.isArrayHandle(value, in: context)
  }

  package static func isDateHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.isDateHandle(value, in: context)
  }

  package static func isInstanceOfHandle(
    _ value: JSValueHandle<MockEngine>,
    constructor: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.isInstanceOfHandle(value, constructor: constructor, in: context)
  }

  package static func looselyEqualsHandle(
    _ lhs: JSValueHandle<MockEngine>,
    _ rhs: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.looselyEqualsHandle(lhs, rhs, in: context)
  }

  package static func strictlyEqualsHandle(
    _ lhs: JSValueHandle<MockEngine>,
    _ rhs: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.strictlyEqualsHandle(lhs, rhs, in: context)
  }

  package static func makeArrayBufferWithBytesNoCopyHandle(
    in context: MockContextHandle,
    bytes: UnsafeMutableRawPointer?,
    byteLength: Int,
    bytesDeallocator: (
      @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
    )?,
    deallocatorContext: UnsafeMutableRawPointer?
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeArrayBufferWithBytesNoCopyHandle(
      in: context,
      bytes: bytes,
      byteLength: byteLength,
      bytesDeallocator: bytesDeallocator,
      deallocatorContext: deallocatorContext
    )
  }

  package static func arrayBufferByteLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    MockDriver.arrayBufferByteLengthForHandle(value, in: context)
  }

  package static func arrayBufferBytesPtrForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    MockDriver.arrayBufferBytesPtrForHandle(value, in: context)
  }

  package static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    length: Int
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeTypedArrayHandle(in: context, kind: kind, length: length)
  }

  package static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<MockEngine>
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeTypedArrayHandle(in: context, kind: kind, arrayBuffer: arrayBuffer)
  }

  package static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<MockEngine>,
    byteOffset: Int,
    length: Int
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeTypedArrayHandle(
      in: context,
      kind: kind,
      arrayBuffer: arrayBuffer,
      byteOffset: byteOffset,
      length: length
    )
  }

  package static func typedArrayLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    MockDriver.typedArrayLengthForHandle(value, in: context)
  }

  package static func typedArrayByteLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    MockDriver.typedArrayByteLengthForHandle(value, in: context)
  }

  package static func typedArrayByteOffsetForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    MockDriver.typedArrayByteOffsetForHandle(value, in: context)
  }

  package static func typedArrayBufferForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.typedArrayBufferForHandle(value, in: context)
  }

  package static func typedArrayBytesPtrForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    MockDriver.typedArrayBytesPtrForHandle(value, in: context)
  }

  package static func isArrayBufferHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.isArrayBufferHandle(value, in: context)
  }

  package static func typedArrayKindForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSTypedArrayKind? {
    MockDriver.typedArrayKindForHandle(value, in: context)
  }
}
