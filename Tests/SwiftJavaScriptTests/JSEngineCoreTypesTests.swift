import Foundation
import Testing

@testable import SwiftJavaScript

public struct MockRuntime: Sendable, Equatable {
  let id: String
}

public struct MockRuntimeHandle: JSRuntimeManualReferenceCountedHandle, @unchecked Sendable {
  let rawRuntime: MockRuntime

  init(rawRuntime: MockRuntime) {
    self.rawRuntime = rawRuntime
  }

  var engineType: MockEngine.Type {
    MockEngine.self
  }

  public func retainReference() -> Bool {
    true
  }

  public func releaseReference() -> Bool {
    true
  }
}

public struct MockContext: Sendable, Equatable {
  let runtimeID: String
}

public struct MockContextHandle: JSContextManualReferenceCountedHandle, @unchecked Sendable {
  let rawContext: MockContext

  init(rawContext: MockContext) {
    self.rawContext = rawContext
  }

  public func bindContextOwner<E>(_ owner: SwiftJavaScript.JSContext<E>)
  where MockContextHandle == E.ContextHandle, E: SwiftJavaScript.JSEngine {

  }

  var engineType: MockEngine.Type {
    MockEngine.self
  }

  public func retainReference() -> Bool {
    true
  }

  public func releaseReference() -> Bool {
    true
  }
}

public struct MockValue: Sendable, Equatable {
  let kind: String
  let payload: String
}

private final class MockValueHandleStorage: @unchecked Sendable {
  let rawValue: MockValue
  private let onReleaseReference: (@Sendable () -> Void)?

  init(rawValue: MockValue, onReleaseReference: (@Sendable () -> Void)? = nil) {
    self.rawValue = rawValue
    self.onReleaseReference = onReleaseReference
  }

  func recordReleaseReference() {
    onReleaseReference?()
  }
}

private final class MockValueReleaseCounter: @unchecked Sendable {
  private(set) var releaseReferenceCount = 0

  func increment() {
    releaseReferenceCount += 1
  }
}

public struct MockClass: Sendable, Equatable, Hashable {
  let id: String
}

public struct MockClassHandle: JSClassManualReferenceCountedHandle, @unchecked Sendable,
  Equatable, Hashable
{
  let rawClass: MockClass

  init(rawClass: MockClass) {
    self.rawClass = rawClass
  }

  public func retainReference() -> Bool {
    true
  }

  public func releaseReference() -> Bool {
    true
  }
}

public final class MockStringHandle: JSPropertyStringKeyManualReferenceCountedHandle,
  JSPreparedScriptManualReferenceCountedHandle, @unchecked Sendable
{
  private let count: Int
  private let storage: UnsafeMutablePointer<UInt16>

  init(_ value: String) {
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

  var length: Int { count }

  var characters: UnsafePointer<UInt16> {
    UnsafePointer(storage)
  }

  var string: String {
    String(decoding: UnsafeBufferPointer(start: characters, count: count), as: UTF16.self)
  }

  @discardableResult
  public func retainReference() -> Bool {
    true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    true
  }
}

public struct MockValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {
  typealias Engine = MockEngine
  typealias RawValue = MockValue

  private let storagePointer: UnsafeMutableRawPointer

  var rawValue: MockValue {
    Unmanaged<MockValueHandleStorage>.fromOpaque(storagePointer).takeUnretainedValue().rawValue
  }

  init(rawValue: MockValue) {
    self.init(rawValue: rawValue, onRelease: nil)
  }

  private init(rawValue: MockValue, onRelease: (@Sendable () -> Void)?) {
    self.storagePointer = Unmanaged.passRetained(
      MockValueHandleStorage(rawValue: rawValue, onReleaseReference: onRelease)
    ).toOpaque()
  }

  static func releaseCounting(
    rawValue: MockValue,
    onRelease: @escaping @Sendable () -> Void
  ) -> MockValueHandle {
    MockValueHandle(rawValue: rawValue, onRelease: onRelease)
  }

  public var storageWords: JSValueStorageWords {
    (
      word0: UInt64(UInt(bitPattern: storagePointer)),
      word1: 0,
      word2: 0
    )
  }

  public init(storageWords: JSValueStorageWords) {
    self.storagePointer = UnsafeMutableRawPointer(bitPattern: UInt(storageWords.word0))!
  }

  var engineType: MockEngine.Type {
    MockEngine.self
  }

  public func retainReference() -> Bool {
    let storage = Unmanaged<MockValueHandleStorage>.fromOpaque(storagePointer).takeUnretainedValue()
    _ = Unmanaged.passRetained(storage)
    return true
  }

  public func releaseReference() -> Bool {
    let storage = Unmanaged<MockValueHandleStorage>.fromOpaque(storagePointer).takeUnretainedValue()
    storage.recordReleaseReference()
    _ = Unmanaged<MockValueHandleStorage>.fromOpaque(storagePointer).takeRetainedValue()
    return true
  }
}

public enum MockEngine: JSEngine {
  public typealias RuntimeHandle = MockRuntimeHandle
  public typealias ContextHandle = MockContextHandle
  public typealias ValueHandle = MockValueHandle
  public typealias ClassHandle = MockClassHandle
  public typealias PropertyStringKeyHandle = MockStringHandle
  public typealias PreparedScriptHandle = MockStringHandle
}

@Test func jsValueHandleStorageWordsRoundTripMockHandlePointerWord() {
  let handle = MockValueHandle(rawValue: MockValue(kind: "number", payload: "42"))
  defer { _ = handle.releaseReference() }

  let storageWords = handle.storageWords

  #expect(storageWords.word1 == 0)
  #expect(storageWords.word2 == 0)

  let restored = MockValueHandle(storageWords: storageWords)
  #expect(restored.rawValue == handle.rawValue)
}

@Test func jsValueHandleStorageWordsKeepThreeWordLayout() {
  #expect(MemoryLayout<JSValueStorageWords>.size == 3 * MemoryLayout<UInt64>.size)
  #expect(MemoryLayout<JSValueStorageWords>.stride == 3 * MemoryLayout<UInt64>.stride)
}

@Test func jsValueDeinitReleasesHandleExactlyOnce() {
  let counter = MockValueReleaseCounter()

  do {
    let value = JSValue<MockEngine>(
      handleValue: .releaseCounting(
        rawValue: MockValue(kind: "object", payload: "deinit"),
        onRelease: counter.increment
      )
    )
    #expect(value.borrowHandle().rawValue.payload == "deinit")
    #expect(counter.releaseReferenceCount == 0)
  }

  #expect(counter.releaseReferenceCount == 1)
}

@Test func jsValueRetainedCopyDeinitReleasesEachWrapper() {
  let counter = MockValueReleaseCounter()

  do {
    let value = JSValue<MockEngine>(
      handleValue: .releaseCounting(
        rawValue: MockValue(kind: "object", payload: "retained"),
        onRelease: counter.increment
      )
    )

    do {
      let retained = JSValue<MockEngine>(retaining: value)
      #expect(retained.borrowHandle().rawValue.payload == "retained")
      #expect(counter.releaseReferenceCount == 0)
    }

    #expect(counter.releaseReferenceCount == 1)
  }

  #expect(counter.releaseReferenceCount == 2)
}

@Test func jsValueTakeHandleSkipsDeinitUntilHandleRelease() {
  let counter = MockValueReleaseCounter()

  let value = JSValue<MockEngine>(
    handleValue: .releaseCounting(
      rawValue: MockValue(kind: "object", payload: "transfer"),
      onRelease: counter.increment
    )
  )
  let transferredHandle = value.takeHandle()

  #expect(counter.releaseReferenceCount == 0)
  #expect(transferredHandle.releaseReference())
  #expect(counter.releaseReferenceCount == 1)
}

private enum MockDriver: JSEngine {
  typealias ValueHandle = MockValueHandle
  typealias ClassHandle = MockClassHandle
  typealias Engine = MockEngine
  typealias RuntimeHandle = MockRuntimeHandle
  typealias ContextHandle = MockContextHandle
  typealias PropertyStringKeyHandle = MockStringHandle
  typealias PreparedScriptHandle = MockStringHandle

  static let capabilities = JSEngineCapabilities(supportsHostObjects: true)

  static func makeRuntime() -> MockRuntime {
    MockRuntime(id: "runtime")
  }

  static func makeContext(in runtime: MockRuntime) -> MockContext {
    MockContext(runtimeID: runtime.id)
  }

  static func evaluateScript(
    _ script: String,
    in context: MockContext,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSResult<MockValue> {
    if script == "throw" {
      return .exception(MockValue(kind: "exception", payload: "\(context.runtimeID):throw"))
    }
    return .value(MockValue(kind: "script", payload: "\(context.runtimeID):\(script)"))
  }

  static func makeString(_ value: String, in context: MockContext) -> MockValue {
    MockValue(kind: "string", payload: "\(context.runtimeID):\(value)")
  }

  static func makeSymbol(_ value: String, in context: MockContext) -> MockValue {
    MockValue(kind: "symbol", payload: "\(context.runtimeID):\(value)")
  }

  static func makeNumber(_ value: Double, in context: MockContext) -> MockValue {
    MockValue(kind: "number", payload: "\(context.runtimeID):\(value)")
  }

  static func makeBoolean(_ value: Bool, in context: MockContext) -> MockValue {
    MockValue(kind: "boolean", payload: "\(context.runtimeID):\(value)")
  }

  static func makeNull(in context: MockContext) -> MockValue {
    MockValue(kind: "null", payload: context.runtimeID)
  }

  static func makeUndefined(in context: MockContext) -> MockValue {
    MockValue(kind: "undefined", payload: context.runtimeID)
  }

  static func makeObject(in context: MockContext) -> JSResult<MockValue> {
    .value(MockValue(kind: "object", payload: context.runtimeID))
  }

  static func makeArray(in context: MockContext) -> JSResult<MockValue> {
    .value(MockValue(kind: "array", payload: context.runtimeID))
  }

  static func propertyNames(on object: MockValue, in context: MockContext) -> [String] {
    [context.runtimeID, object.kind, object.payload]
  }

  static func getProperty(_ key: String, on object: MockValue, in context: MockContext)
    -> JSResult<MockValue>
  {
    .value(MockValue(kind: "property", payload: "\(context.runtimeID):\(object.payload):\(key)"))
  }

  static func getProperty(_ key: MockValue, on object: MockValue, in context: MockContext)
    -> JSResult<MockValue>
  {
    .value(
      MockValue(kind: "property", payload: "\(context.runtimeID):\(object.payload):\(key.payload)"))
  }

  static func getProperty(at index: UInt32, on object: MockValue, in context: MockContext)
    -> JSResult<MockValue>
  {
    .value(MockValue(kind: "index", payload: "\(context.runtimeID):\(object.payload):\(index)"))
  }

  static func hasProperty(_ key: String, on object: MockValue, in context: MockContext) -> Bool {
    object.payload.contains(key)
  }

  static func hasProperty(_ key: MockValue, on object: MockValue, in context: MockContext) -> Bool {
    object.payload.contains(key.payload)
  }

  static func deleteProperty(_ key: String, on object: MockValue, in context: MockContext)
    -> JSResult<Void>
  {
    .value(())
  }

  static func deleteProperty(_ key: MockValue, on object: MockValue, in context: MockContext)
    -> JSResult<Void>
  {
    .value(())
  }

  static func callFunction(
    _ function: MockValue,
    this thisValue: MockValue?,
    arguments: [MockValue],
    in context: MockContext
  ) -> JSResult<MockValue> {
    .value(
      MockValue(
        kind: "call", payload: "\(context.runtimeID):\(function.payload):\(arguments.count)"))
  }

  static func construct(_ constructor: MockValue, arguments: [MockValue], in context: MockContext)
    -> JSResult<MockValue>
  {
    .value(MockValue(kind: "construct", payload: "\(context.runtimeID):\(arguments.count)"))
  }

  static func toObject(_ value: MockValue, in context: MockContext) -> JSResult<MockValue> {
    .value(MockValue(kind: "object", payload: value.payload))
  }

  static func isArray(_ value: MockValue, in context: MockContext) -> Bool {
    value.kind == "array"
  }

  static func isDate(_ value: MockValue, in context: MockContext) -> Bool {
    value.kind == "date"
  }

  static func isInstanceOf(_ value: MockValue, constructor: MockValue, in context: MockContext)
    -> Bool
  {
    value.payload == constructor.payload
  }

  static func looselyEquals(_ lhs: MockValue, _ rhs: MockValue, in context: MockContext) -> Bool {
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

  static func strictlyEquals(
    _ lhs: MockValue,
    _ rhs: MockValue,
    in context: MockContext
  ) -> Bool {
    _ = context
    return lhs == rhs
  }

  static func setProperty(
    _ key: String,
    on object: MockValue,
    to value: MockValue,
    in context: MockContext,
    attributes: JSHostMemberAttributes
  ) -> JSResult<Void> {
    .value(())
  }

  static func setProperty(
    _ key: MockValue,
    on object: MockValue,
    to value: MockValue,
    in context: MockContext,
    attributes: JSHostMemberAttributes
  ) -> JSResult<Void> {
    .value(())
  }

  static func setProperty(
    at index: UInt32, on object: MockValue, to value: MockValue, in context: MockContext
  )
    -> JSResult<Void>
  {
    .value(())
  }

}

extension MockDriver {
  fileprivate static func resultHandle(from result: JSResult<MockValue>)
    -> JSResult<JSValueHandle<MockEngine>>
  {
    switch result {
    case .value(let value):
      return .value(JSValueHandle<MockEngine>(rawValue: value))
    case .exception(let exception):
      return .exception(JSValueHandle<MockEngine>(rawValue: exception))
    }
  }

  fileprivate static func makeRuntimeHandle() -> MockRuntimeHandle {
    MockRuntimeHandle(rawRuntime: makeRuntime())
  }

  fileprivate static func makeBorrowedContextHandleFromRuntime(
    in runtime: MockRuntimeHandle
  ) -> MockContextHandle? {
    return MockContextHandle(rawContext: makeContext(in: runtime.rawRuntime))
  }

  fileprivate static func globalObjectValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    return JSValueHandle<MockEngine>(
      rawValue: MockValue(kind: "object", payload: "\(context.rawContext.runtimeID):global"))
  }

  fileprivate static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<MockEngine>,
    in context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    _ = callback

    return JSValueHandle<MockEngine>(
      rawValue: MockValue(kind: "function", payload: "\(context.rawContext.runtimeID):\(name)"))
  }

  fileprivate static func makeStringValueHandle(
    _ value: String,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {

    return JSValueHandle<MockEngine>(rawValue: makeString(value, in: context.rawContext))
  }

  fileprivate static func makeNumberValueHandle(
    _ value: Double,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {

    return JSValueHandle<MockEngine>(rawValue: makeNumber(value, in: context.rawContext))
  }

  fileprivate static func makeSymbolValueHandle(
    _ value: String,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {

    return JSValueHandle<MockEngine>(rawValue: makeSymbol(value, in: context.rawContext))
  }

  fileprivate static func makeNullValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    return JSValueHandle<MockEngine>(rawValue: makeNull(in: context.rawContext))
  }

  fileprivate static func makeUndefinedValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {

    return JSValueHandle<MockEngine>(rawValue: makeUndefined(in: context.rawContext))
  }

  fileprivate static func makeObjectResultHandle(
    _ context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    return resultHandle(from: makeObject(in: context.rawContext))
  }

  fileprivate static func makeArrayResultHandle(
    _ context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    return resultHandle(from: makeArray(in: context.rawContext))
  }

  fileprivate static func makePreparedScriptHandle(
    _ source: String,
    in context: MockContextHandle
  ) -> MockStringHandle? {
    _ = context
    return MockStringHandle(source)
  }

  fileprivate static func isPreparedScriptHandleCompatibleWithContext(
    _ script: MockStringHandle,
    in context: MockContextHandle
  ) -> Bool {
    _ = script
    _ = context
    return true
  }

  fileprivate static func evaluatePreparedScriptResultHandle(
    _ script: MockStringHandle,
    _ context: MockContextHandle,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    return resultHandle(
      from: evaluateScript(
        script.string,
        in: context.rawContext,
        sourceURL: sourceURL,
        startingLineNumber: startingLineNumber
      )
    )
  }

  fileprivate static func valueTypeForHandle(
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

  fileprivate static func toBooleanForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    _ = context
    return !value.rawValue.payload.isEmpty
  }

  fileprivate static func toNumberForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Double {
    _ = context
    return Double(value.rawValue.payload) ?? .nan
  }

  fileprivate static func toStringForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> String? {
    _ = context
    return value.rawValue.payload
  }

  fileprivate static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {

    return JSValueHandle<MockEngine>(rawValue: makeBoolean(value, in: context.rawContext))
  }

  fileprivate static func propertyNamesForHandle(
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> [String]? {

    return propertyNames(on: object.rawValue, in: context.rawContext)
  }

  fileprivate static func makePropertyStringKeyHandle(
    _ value: String,
    in context: MockContextHandle
  ) -> MockStringHandle? {
    _ = context
    return MockStringHandle(value)
  }

  fileprivate static func makeStringValueHandle(
    fromPropertyStringKey key: MockStringHandle,
    in context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    makeStringValueHandle(key.string, context)
  }

  fileprivate static func isPropertyStringKeyHandleCompatibleWithContext(
    _ key: MockStringHandle,
    in context: MockContextHandle
  ) -> Bool {
    _ = key
    _ = context
    return true
  }

  fileprivate static func getPropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    return resultHandle(from: getProperty(key.string, on: object.rawValue, in: context.rawContext))
  }

  fileprivate static func setPropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {

    switch setProperty(
      key.string,
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

  fileprivate static func getValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    return resultHandle(
      from: getProperty(key.rawValue, on: object.rawValue, in: context.rawContext))
  }

  fileprivate static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    return resultHandle(from: getProperty(at: index, on: object.rawValue, in: context.rawContext))
  }

  fileprivate static func setValuePropertyHandle(
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

  fileprivate static func setIndexPropertyHandle(
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

  fileprivate static func hasPropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {

    return hasProperty(key.string, on: object.rawValue, in: context.rawContext)
  }

  fileprivate static func hasValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {

    return hasProperty(key.rawValue, on: object.rawValue, in: context.rawContext)
  }

  fileprivate static func deletePropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {

    switch deleteProperty(key.string, on: object.rawValue, in: context.rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  fileprivate static func deleteValuePropertyHandle(
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

  fileprivate static func callFunctionHandle(
    _ function: JSValueHandle<MockEngine>,
    this thisValue: JSValueHandle<MockEngine>? = nil,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    let rawThisValue: MockValue? = thisValue?.rawValue
    let rawArguments = arguments.map(\.rawValue)
    return resultHandle(
      from: callFunction(
        function.rawValue,
        this: rawThisValue,
        arguments: rawArguments,
        in: context.rawContext
      )
    )
  }

  fileprivate static func constructHandle(
    _ constructor: JSValueHandle<MockEngine>,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    let rawArguments = arguments.map(\.rawValue)
    return resultHandle(
      from: construct(constructor.rawValue, arguments: rawArguments, in: context.rawContext))
  }

  fileprivate static func toObjectHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {

    return resultHandle(from: toObject(value.rawValue, in: context.rawContext))
  }

  fileprivate static func isArrayHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {

    return isArray(value.rawValue, in: context.rawContext)
  }

  fileprivate static func isDateHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {

    return isDate(value.rawValue, in: context.rawContext)
  }

  fileprivate static func isInstanceOfHandle(
    _ value: JSValueHandle<MockEngine>,
    constructor: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {

    return isInstanceOf(value.rawValue, constructor: constructor.rawValue, in: context.rawContext)
  }

  fileprivate static func looselyEqualsHandle(
    _ lhs: JSValueHandle<MockEngine>,
    _ rhs: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    looselyEquals(lhs.rawValue, rhs.rawValue, in: context.rawContext)
  }

  fileprivate static func strictlyEqualsHandle(
    _ lhs: JSValueHandle<MockEngine>,
    _ rhs: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    strictlyEquals(lhs.rawValue, rhs.rawValue, in: context.rawContext)
  }

  fileprivate static func makeArrayBufferWithBytesNoCopyHandle(
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

  fileprivate static func arrayBufferByteLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  fileprivate static func arrayBufferBytesPtrForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    _ = value
    _ = context
    return (nil, false)
  }

  fileprivate static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    length: Int
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = length
    return nil
  }

  fileprivate static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<MockEngine>
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = arrayBuffer
    return nil
  }

  fileprivate static func makeTypedArrayHandle(
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

  fileprivate static func typedArrayLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  fileprivate static func typedArrayByteLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  fileprivate static func typedArrayByteOffsetForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  fileprivate static func typedArrayBufferForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    _ = value
    _ = context
    return nil
  }

  fileprivate static func typedArrayBytesPtrForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    _ = value
    _ = context
    return (nil, false)
  }

  fileprivate static func isArrayBufferHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    _ = value
    _ = context
    return false
  }

  fileprivate static func typedArrayKindForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSTypedArrayKind? {
    _ = value
    _ = context
    return nil
  }
}

extension MockEngine {
  public static var capabilities: JSEngineCapabilities {
    MockDriver.capabilities
  }

  public static func makeRuntimeHandle() -> MockRuntimeHandle {
    MockDriver.makeRuntimeHandle()
  }

  public static func makeBorrowedContextHandleFromRuntime(
    in runtime: MockRuntimeHandle
  ) -> MockContextHandle? {
    MockDriver.makeBorrowedContextHandleFromRuntime(in: runtime)
  }

  public static func globalObjectValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.globalObjectValueHandle(context)
  }

  public static func makeFunctionValueHandle(
    named name: String,
    callback: @escaping JSFunctionCallback<MockEngine>,
    in context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeFunctionValueHandle(named: name, callback: callback, in: context)
  }

  public static func makePreparedScriptHandle(
    _ source: String,
    in context: MockContextHandle
  ) -> MockStringHandle? {
    MockDriver.makePreparedScriptHandle(source, in: context)
  }

  public static func isPreparedScriptHandleCompatibleWithContext(
    _ script: MockStringHandle,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.isPreparedScriptHandleCompatibleWithContext(script, in: context)
  }

  public static func evaluatePreparedScriptResultHandle(
    _ script: MockStringHandle,
    _ context: MockContextHandle,
    sourceURL: String? = nil,
    startingLineNumber: Int32 = 1
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.evaluatePreparedScriptResultHandle(
      script,
      context,
      sourceURL: sourceURL,
      startingLineNumber: startingLineNumber
    )
  }

  public static func valueTypeForHandle(
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

  public static func toBooleanForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    _ = context
    return !value.rawValue.payload.isEmpty
  }

  public static func toNumberForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Double {
    _ = context
    return Double(value.rawValue.payload) ?? .nan
  }

  public static func toStringForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> String? {
    _ = context
    return value.rawValue.payload
  }

  public static func makeStringValueHandle(
    _ value: String,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeStringValueHandle(value, context)
  }

  public static func makeSymbolValueHandle(
    _ value: String,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeSymbolValueHandle(value, context)
  }

  public static func makeNumberValueHandle(
    _ value: Double,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeNumberValueHandle(value, context)
  }

  public static func makeBooleanValueHandle(
    _ value: Bool,
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {

    return JSValueHandle<MockEngine>(
      rawValue: MockDriver.makeBoolean(value, in: context.rawContext))
  }

  public static func makeNullValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeNullValueHandle(context)
  }

  public static func makeUndefinedValueHandle(
    _ context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeUndefinedValueHandle(context)
  }

  public static func makeObjectResultHandle(
    _ context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.makeObjectResultHandle(context)
  }

  public static func makeArrayResultHandle(
    _ context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.makeArrayResultHandle(context)
  }

  public static func propertyNamesForHandle(
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> [String]? {
    MockDriver.propertyNamesForHandle(on: object, in: context)
  }

  public static func makePropertyStringKeyHandle(
    _ value: String,
    in context: MockContextHandle
  ) -> MockStringHandle? {
    MockDriver.makePropertyStringKeyHandle(value, in: context)
  }

  public static func makeStringValueHandle(
    fromPropertyStringKey key: MockStringHandle,
    in context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    MockDriver.makeStringValueHandle(fromPropertyStringKey: key, in: context)
  }

  public static func isPropertyStringKeyHandleCompatibleWithContext(
    _ key: MockStringHandle,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.isPropertyStringKeyHandleCompatibleWithContext(key, in: context)
  }

  public static func getPropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.getPropertyStringKeyHandle(key, on: object, in: context)
  }

  public static func setPropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    MockDriver.setPropertyStringKeyHandle(
      key,
      on: object,
      to: value,
      in: context,
      attributes: attributes
    )
  }

  public static func getValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.getValuePropertyHandle(key, on: object, in: context)
  }

  public static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.getIndexPropertyHandle(at: index, on: object, in: context)
  }

  public static func setValuePropertyHandle(
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

  public static func setIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<MockEngine>,
    to value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.setIndexPropertyHandle(at: index, on: object, to: value, in: context)
  }

  public static func hasPropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.hasPropertyStringKeyHandle(key, on: object, in: context)
  }

  public static func hasValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.hasValuePropertyHandle(key, on: object, in: context)
  }

  public static func deletePropertyStringKeyHandle(
    _ key: MockStringHandle,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.deletePropertyStringKeyHandle(key, on: object, in: context)
  }

  public static func deleteValuePropertyHandle(
    _ key: JSValueHandle<MockEngine>,
    on object: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    MockDriver.deleteValuePropertyHandle(key, on: object, in: context)
  }

  public static func callFunctionHandle(
    _ function: JSValueHandle<MockEngine>,
    this thisValue: JSValueHandle<MockEngine>? = nil,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.callFunctionHandle(
      function, this: thisValue, arguments: arguments, in: context)
  }

  public static func constructHandle(
    _ constructor: JSValueHandle<MockEngine>,
    arguments: [JSValueHandle<MockEngine>] = [],
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.constructHandle(constructor, arguments: arguments, in: context)
  }

  public static func toObjectHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSResult<JSValueHandle<MockEngine>>? {
    MockDriver.toObjectHandle(value, in: context)
  }

  public static func isArrayHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.isArrayHandle(value, in: context)
  }

  public static func isDateHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.isDateHandle(value, in: context)
  }

  public static func isInstanceOfHandle(
    _ value: JSValueHandle<MockEngine>,
    constructor: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.isInstanceOfHandle(value, constructor: constructor, in: context)
  }

  public static func looselyEqualsHandle(
    _ lhs: JSValueHandle<MockEngine>,
    _ rhs: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.looselyEqualsHandle(lhs, rhs, in: context)
  }

  public static func strictlyEqualsHandle(
    _ lhs: JSValueHandle<MockEngine>,
    _ rhs: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool? {
    MockDriver.strictlyEqualsHandle(lhs, rhs, in: context)
  }

  public static func makeArrayBufferWithBytesNoCopyHandle(
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

  public static func arrayBufferByteLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  public static func arrayBufferBytesPtrForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    _ = value
    _ = context
    return (nil, false)
  }

  public static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    length: Int
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = length
    return nil
  }

  public static func makeTypedArrayHandle(
    in context: MockContextHandle,
    kind: JSTypedArrayKind,
    arrayBuffer: JSValueHandle<MockEngine>
  ) -> JSValueHandle<MockEngine>? {
    _ = context
    _ = kind
    _ = arrayBuffer
    return nil
  }

  public static func makeTypedArrayHandle(
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

  public static func typedArrayLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  public static func typedArrayByteLengthForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  public static func typedArrayByteOffsetForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Int? {
    _ = value
    _ = context
    return nil
  }

  public static func typedArrayBufferForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSValueHandle<MockEngine>? {
    _ = value
    _ = context
    return nil
  }

  public static func typedArrayBytesPtrForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> (bytes: UnsafeMutableRawPointer?, hadException: Bool) {
    _ = value
    _ = context
    return (nil, false)
  }

  public static func isArrayBufferHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> Bool {
    _ = value
    _ = context
    return false
  }

  public static func typedArrayKindForHandle(
    _ value: JSValueHandle<MockEngine>,
    in context: MockContextHandle
  ) -> JSTypedArrayKind? {
    _ = value
    _ = context
    return nil
  }
}

@Test func engineCapabilitiesDefaultsToDisabled() {
  let capabilities = JSEngineCapabilities()

  #expect(!capabilities.supportsBigInt)
  #expect(!capabilities.supportsSymbol)
  #expect(!capabilities.supportsExternalArrayBuffer)
  #expect(!capabilities.supportsHostObjects)
  #expect(!capabilities.supportsESModules)
  #expect(!capabilities.supportsPromiseJobQueueControl)
}

@Test func hostModuleDescriptorKeepsTypeMetadata() {
  let descriptor = JSHostModuleDescriptor(
    name: "Console",
    functions: [
      JSHostFunctionDescriptor(name: "log", binding: "console_log")
    ],
    constants: [
      JSHostConstantDescriptor(name: "version", value: "1.0.0")
    ],
    types: [
      JSHostTypeDescriptor(
        name: "Timer",
        constructor: JSHostConstructorDescriptor(binding: "timer_ctor"),
        methods: [JSHostFunctionDescriptor(name: "start", binding: "timer_start")],
        staticMethods: [JSHostFunctionDescriptor(name: "now", binding: "timer_now")],
        properties: [
          JSHostPropertyDescriptor(
            name: "running",
            getterBinding: "timer_get_running",
            setterBinding: "timer_set_running"
          )
        ],
        parent: "EventTarget",
        storagePolicy: .swiftRetainedObject,
        initializerBinding: "timer_initialize",
        finalizerBinding: "timer_finalize",
        dynamicPropertyGetterBinding: "timer_dynamic_get",
        propertyEnumeratorBinding: "timer_dynamic_enumerate",
        callAsFunctionBinding: "timer_call"
      )
    ]
  )

  #expect(descriptor.name == "Console")
  #expect(descriptor.functions.count == 1)
  #expect(descriptor.constants.count == 1)
  #expect(descriptor.types.count == 1)
  #expect(descriptor.types[0].parent == "EventTarget")
  #expect(descriptor.types[0].methods[0].binding == "timer_start")
  #expect(descriptor.types[0].initializerBinding == "timer_initialize")
  #expect(descriptor.types[0].dynamicPropertyGetterBinding == "timer_dynamic_get")
  #expect(descriptor.types[0].propertyEnumeratorBinding == "timer_dynamic_enumerate")
  #expect(descriptor.types[0].callAsFunctionBinding == "timer_call")
}

@Test func genericHandlesKeepRawStorageAndEngineTyping() {
  let runtime = MockRuntimeHandle(rawRuntime: MockRuntime(id: "runtime-token"))
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "runtime-token"))
  let value = JSValueHandle<MockEngine>(rawValue: MockValue(kind: "string", payload: "value-token"))

  let runtimeToken = runtime.rawRuntime
  let contextToken = context.rawContext
  let valueToken = value.rawValue
  let runtimeIsMock = runtime.engineType == MockEngine.self
  let contextIsMock = context.engineType == MockEngine.self
  let valueIsMock = value.engineType == MockEngine.self

  #expect(runtimeToken == MockRuntime(id: "runtime-token"))
  #expect(contextToken == MockContext(runtimeID: "runtime-token"))
  #expect(valueToken == MockValue(kind: "string", payload: "value-token"))
  #expect(runtimeIsMock)
  #expect(contextIsMock)
  #expect(valueIsMock)
}

@Test func engineValuePreservesHandleAndEngineType() {
  let handle = JSValueHandle<MockEngine>(rawValue: MockValue(kind: "string", payload: "mock-value"))
  let value = JSValue<MockEngine>(handleValue: handle)

  let storedHandle = value.borrowHandle()

  #expect(storedHandle.rawValue == MockValue(kind: "string", payload: "mock-value"))
  #expect(storedHandle.engineType == MockEngine.self)
}

@Test func engineValueKeepsOpaquePayloadIdentity() {
  let payload = MockValue(kind: "number", payload: "runtime:7")
  let handle = JSValueHandle<MockEngine>(rawValue: payload)
  let value = JSValue<MockEngine>(handleValue: handle)

  let roundtrip = value.borrowHandle().rawValue

  #expect(roundtrip == payload)
}

@Test func engineValueShellKeepsHandleAndEngineTyping() {
  let handle = JSValueHandle<MockEngine>(
    rawValue: MockValue(kind: "string", payload: "moved-jsvalue"))
  let value = JSValue<MockEngine>(handleValue: handle)

  let roundtripHandle = value.borrowHandle()
  #expect(roundtripHandle.rawValue == MockValue(kind: "string", payload: "moved-jsvalue"))
  #expect(roundtripHandle.engineType == MockEngine.self)
}

@Test func genericResultHandleWrapsValueAndExceptionStates() {
  let valueHandle = JSValueHandle<MockEngine>(
    rawValue: MockValue(kind: "string", payload: "mock-value")
  )
  let exceptionHandle = JSValueHandle<MockEngine>(
    rawValue: MockValue(kind: "exception", payload: "mock-error")
  )

  let valueResult = JSResult<JSValueHandle<MockEngine>>.value(valueHandle)
  let exceptionResult = JSResult<JSValueHandle<MockEngine>>.exception(exceptionHandle)

  let valueIsException = valueResult.isException
  let exceptionIsException = exceptionResult.isException

  #expect(!valueIsException)
  #expect(exceptionIsException)

  switch consume valueResult {
  case .value(let wrapped):
    #expect(wrapped.rawValue == MockValue(kind: "string", payload: "mock-value"))
  case .exception:
    Issue.record("Expected value result case")
  }

  switch consume exceptionResult {
  case .value:
    Issue.record("Expected exception result case")
  case .exception(let wrapped):
    #expect(wrapped.rawValue == MockValue(kind: "exception", payload: "mock-error"))
  }
}

@Test func genericHandlesBridgeThroughDriverProtocol() {
  let runtime = MockDriver.makeRuntimeHandle()
  let context = MockDriver.makeBorrowedContextHandleFromRuntime(in: runtime)

  guard let context else {
    Issue.record("Expected context handle from driver")
    return
  }

  let stringValue = MockDriver.makeStringValueHandle("hello", context)
  let symbolValue = MockDriver.makeSymbolValueHandle("token", context)
  let numberValue = MockDriver.makeNumberValueHandle(42, context)
  let script = MockDriver.makePreparedScriptHandle("1 + 2", in: context)
  let throwingScript = MockDriver.makePreparedScriptHandle("throw", in: context)
  let evalValue = script.map { MockDriver.evaluatePreparedScriptResultHandle($0, context) } ?? nil
  let evalException =
    throwingScript.map { MockDriver.evaluatePreparedScriptResultHandle($0, context) } ?? nil

  guard
    let stringValue, let symbolValue, let numberValue, let script, let throwingScript,
    let evalValue,
    let evalException
  else {
    Issue.record("Expected driver bridge operations to produce handles")
    return
  }
  defer {
    _ = script.releaseReference()
    _ = throwingScript.releaseReference()
  }

  let names = MockDriver.propertyNamesForHandle(on: stringValue, in: context)
  let messageKey = MockDriver.makePropertyStringKeyHandle("message", in: context)
  guard let messageKey else {
    Issue.record("Expected property string key handle")
    return
  }
  defer { _ = messageKey.releaseReference() }
  let property = MockDriver.getPropertyStringKeyHandle(
    messageKey, on: stringValue, in: context)
  let propertySet = MockDriver.setPropertyStringKeyHandle(
    messageKey,
    on: stringValue,
    to: numberValue,
    in: context,
    attributes: [.readOnly]
  )

  #expect(propertySet)
  #expect(names == ["runtime", "string", "runtime:hello"])
  #expect(
    symbolValue.rawValue
      == MockValue(kind: "symbol", payload: "runtime:token"))

  switch consume evalValue {
  case .value(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "script", payload: "runtime:1 + 2"))
  case .exception:
    Issue.record("Expected script evaluation to succeed")
  }

  switch consume evalException {
  case .value:
    Issue.record("Expected script evaluation to surface exception result")
  case .exception(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "exception", payload: "runtime:throw"))
  }

  guard let property else {
    Issue.record("Expected property handle result")
    return
  }

  switch consume property {
  case .value(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "property", payload: "runtime:runtime:hello:message"))
  case .exception:
    Issue.record("Expected property access to succeed")
  }
}

@Test func genericHandlesBridgeObjectsCallsAndTypeHelpers() {
  let runtime = MockDriver.makeRuntimeHandle()
  let context = MockDriver.makeBorrowedContextHandleFromRuntime(in: runtime)

  guard let context else {
    Issue.record("Expected context handle from driver")
    return
  }

  let object = MockDriver.makeObjectResultHandle(context)
  let array = MockDriver.makeArrayResultHandle(context)
  let function = MockDriver.makeStringValueHandle("callable", context)
  let argument = MockDriver.makeNumberValueHandle(7, context)
  let primitive = MockDriver.makeStringValueHandle("boxed", context)
  let constructor = MockDriver.makeStringValueHandle("boxed", context)
  let nullValue = MockDriver.makeNullValueHandle(context)
  let undefinedValue = MockDriver.makeUndefinedValueHandle(context)

  guard let object, let array, let function, let argument, let primitive, let constructor,
    let nullValue, let undefinedValue
  else {
    Issue.record("Expected object/array/call scaffolding handles")
    return
  }

  let callResult = MockDriver.callFunctionHandle(
    function, arguments: [argument], in: context)
  let constructResult = MockDriver.constructHandle(
    function, arguments: [argument], in: context)
  let boxedResult = MockDriver.toObjectHandle(primitive, in: context)
  let isArray = MockDriver.isArrayHandle(function, in: context)
  let isDate = MockDriver.isDateHandle(function, in: context)
  let isInstanceOf = MockDriver.isInstanceOfHandle(
    primitive, constructor: constructor, in: context)

  switch consume object {
  case .value(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "object", payload: "runtime"))
  case .exception:
    Issue.record("Expected object creation to succeed")
  }

  switch consume array {
  case .value(let value):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "array", payload: "runtime"))
  case .exception:
    Issue.record("Expected array creation to succeed")
  }

  switch consume callResult {
  case .some(.value(let value)):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "call", payload: "runtime:runtime:callable:1"))
  default:
    Issue.record("Expected function call to succeed")
  }

  switch consume constructResult {
  case .some(.value(let value)):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "construct", payload: "runtime:1"))
  default:
    Issue.record("Expected constructor call to succeed")
  }

  switch consume boxedResult {
  case .some(.value(let value)):
    let raw = value.rawValue
    #expect(raw == MockValue(kind: "object", payload: "runtime:boxed"))
  default:
    Issue.record("Expected toObject bridge to succeed")
  }

  #expect(isArray == false)
  #expect(isDate == false)
  #expect(isInstanceOf == true)
  #expect(nullValue.rawValue == MockValue(kind: "null", payload: "runtime"))
  #expect(
    undefinedValue.rawValue
      == MockValue(kind: "undefined", payload: "runtime"))
}

@Test func genericValueEqualityUsesDriverHooks() async {
  let context = JSContext<MockEngine>()

  await context.withInstantContext { context in
    let oneNumber = JSValue<MockEngine>(number: 1, in: context)
    let oneString = JSValue<MockEngine>(string: "1.0", in: context)
    let oneNumberCopy = JSValue<MockEngine>(number: 1, in: context)
    let twoNumber = JSValue<MockEngine>(number: 2, in: context)

    let looselyEqual = oneNumber.looselyEquals(oneString, in: context)
    let looselyNotEqual = !oneNumber.looselyEquals(twoNumber, in: context)
    let strictlyEqual = oneNumber.strictlyEquals(oneNumberCopy, in: context)
    let strictlyNotEqual = !oneNumber.strictlyEquals(oneString, in: context)

    #expect(looselyEqual)
    #expect(looselyNotEqual)
    #expect(strictlyEqual)
    #expect(strictlyNotEqual)
  }
}
