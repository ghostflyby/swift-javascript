import SwiftJavaScript
import Testing

// MARK: - `JSValue` conformers after the value-operation migration
//
// Slice 2 of the dehandle migration moved conversions, equality and every
// property/invocation operation onto the engine value types; core only keeps
// the eight `type()`-derived predicates. The conformers below therefore state
// every other requirement explicitly (the Copyable one is the control that the
// same surface is usable without `~Copyable`), and the predicate test is what
// proves the remaining core extension is reachable from a noncopyable value.

private struct NonCopyableSurfaceValue: SwiftJavaScript.JSValue, ~Copyable {
  typealias Context = MockSurfaceContext
  typealias ContextHandle = MockContextHandle
  typealias ValueHandle = MockValueHandle
  typealias InstantContext = MockSurfaceInstantContext

  let handle: MockValueHandle
  let context: MockContextHandle
  let storedType: JSType

  init(handle: MockValueHandle, context: MockContextHandle, storedType: JSType) {
    self.handle = handle
    self.context = context
    self.storedType = storedType
  }

  borrowing func borrowHandle() -> MockValueHandle {
    handle
  }

  var contextHandle: MockContextHandle {
    context
  }

  func type() -> JSType {
    storedType
  }

  func asCallArgument() -> MockSurfaceCallArgument {
    MockSurfaceCallArgument(handle: handle)
  }

  // Slice 2 of the dehandle migration removed the core conversion/equality and
  // value-operation defaults, so every one of those requirements is stated
  // here explicitly. The bodies route to the module's real mock value view over
  // the same identity, so the double exercises the engine path instead of a
  // second hand-rolled copy.
  private var delegate: MockSurfaceValue {
    MockSurfaceValue(handle: handle, contextHandle: context)
  }

  func toString() -> String {
    delegate.toString()
  }

  func toNumber() -> Double {
    delegate.toNumber()
  }

  func toBoolean() -> Bool {
    delegate.toBoolean()
  }

  func looselyEquals(_ other: borrowing NonCopyableSurfaceValue) -> Bool {
    delegate.looselyEquals(other.delegate)
  }

  func strictlyEquals(_ other: borrowing NonCopyableSurfaceValue) -> Bool {
    delegate.strictlyEquals(other.delegate)
  }

  // MARK: Property access

  func getProperty(
    _ key: StaticString,
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.getProperty(key, in: context)
  }

  func getProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.getProperty(key, in: context)
  }

  func getProperty(
    at index: Int,
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.getProperty(at: index, in: context)
  }

  func setProperty(
    _ key: StaticString,
    to value: borrowing NonCopyableSurfaceValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.setProperty(key, to: value.delegate, attributes: attributes, in: context)
  }

  func setProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    to value: borrowing NonCopyableSurfaceValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.setProperty(key, to: value.delegate, attributes: attributes, in: context)
  }

  func setProperty(
    at index: Int,
    to value: borrowing NonCopyableSurfaceValue,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.setProperty(at: index, to: value.delegate, in: context)
  }

  func deleteProperty(
    _ key: StaticString,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.deleteProperty(key, in: context)
  }

  func deleteProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.deleteProperty(key, in: context)
  }

  func hasProperty(
    _ key: StaticString,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.hasProperty(key, in: context)
  }

  func hasProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.hasProperty(key, in: context)
  }

  func propertyNames(in context: borrowing MockSurfaceInstantContext) -> [String] {
    delegate.propertyNames(in: context)
  }

  // MARK: Invocation

  func call(
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.call(arguments: arguments, in: context)
  }

  func call(
    this thisValue: borrowing NonCopyableSurfaceValue,
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.call(this: thisValue.delegate, arguments: arguments, in: context)
  }

  func call(
    this thisValue: borrowing MockSurfaceCallbackValue,
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.call(this: thisValue, arguments: arguments, in: context)
  }

  func construct(
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.construct(arguments: arguments, in: context)
  }

  func invokeMethod(
    _ name: StaticString,
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.invokeMethod(name, arguments: arguments, in: context)
  }

  func invokeMethod(
    _ name: borrowing MockSurfacePropertyStringKey,
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.invokeMethod(name, arguments: arguments, in: context)
  }

  // MARK: Object conversion and classification

  func toObject(
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.toObject(in: context)
  }

  func isArray(in context: borrowing MockSurfaceInstantContext) -> Bool {
    delegate.isArray(in: context)
  }

  func isDate(in context: borrowing MockSurfaceInstantContext) -> Bool {
    delegate.isDate(in: context)
  }

  func isInstanceOf(
    _ constructor: borrowing NonCopyableSurfaceValue,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.isInstanceOf(constructor.delegate, in: context)
  }

  func isArrayBuffer(in context: borrowing MockSurfaceInstantContext) -> Bool {
    delegate.isArrayBuffer(in: context)
  }

  func isTypedArray(in context: borrowing MockSurfaceInstantContext) -> Bool {
    delegate.isTypedArray(in: context)
  }

  // MARK: Callback-value parameters

  func setProperty(
    _ key: StaticString,
    to value: borrowing MockSurfaceCallbackValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.setProperty(key, to: value, attributes: attributes, in: context)
  }

  func setProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    to value: borrowing MockSurfaceCallbackValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.setProperty(key, to: value, attributes: attributes, in: context)
  }

  func isInstanceOf(
    _ constructor: borrowing MockSurfaceCallbackValue,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.isInstanceOf(constructor, in: context)
  }
}

private struct CopyableSurfaceValue: SwiftJavaScript.JSValue {
  typealias Context = MockSurfaceContext
  typealias ContextHandle = MockContextHandle
  typealias ValueHandle = MockValueHandle
  typealias InstantContext = MockSurfaceInstantContext

  let handle: MockValueHandle
  let context: MockContextHandle
  let storedType: JSType

  init(handle: MockValueHandle, context: MockContextHandle, storedType: JSType) {
    self.handle = handle
    self.context = context
    self.storedType = storedType
  }

  borrowing func borrowHandle() -> MockValueHandle {
    handle
  }

  var contextHandle: MockContextHandle {
    context
  }

  func type() -> JSType {
    storedType
  }

  func asCallArgument() -> MockSurfaceCallArgument {
    MockSurfaceCallArgument(handle: handle)
  }

  // Same explicit witnesses as the noncopyable double: slice 2 removed the
  // core defaults for every requirement except the eight `type()`-derived
  // predicates.
  private var delegate: MockSurfaceValue {
    MockSurfaceValue(handle: handle, contextHandle: context)
  }

  func toString() -> String {
    delegate.toString()
  }

  func toNumber() -> Double {
    delegate.toNumber()
  }

  func toBoolean() -> Bool {
    delegate.toBoolean()
  }

  func looselyEquals(_ other: borrowing CopyableSurfaceValue) -> Bool {
    delegate.looselyEquals(other.delegate)
  }

  func strictlyEquals(_ other: borrowing CopyableSurfaceValue) -> Bool {
    delegate.strictlyEquals(other.delegate)
  }

  // MARK: Property access

  func getProperty(
    _ key: StaticString,
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.getProperty(key, in: context)
  }

  func getProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.getProperty(key, in: context)
  }

  func getProperty(
    at index: Int,
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.getProperty(at: index, in: context)
  }

  func setProperty(
    _ key: StaticString,
    to value: borrowing CopyableSurfaceValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.setProperty(key, to: value.delegate, attributes: attributes, in: context)
  }

  func setProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    to value: borrowing CopyableSurfaceValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.setProperty(key, to: value.delegate, attributes: attributes, in: context)
  }

  func setProperty(
    at index: Int,
    to value: borrowing CopyableSurfaceValue,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.setProperty(at: index, to: value.delegate, in: context)
  }

  func deleteProperty(
    _ key: StaticString,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.deleteProperty(key, in: context)
  }

  func deleteProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.deleteProperty(key, in: context)
  }

  func hasProperty(
    _ key: StaticString,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.hasProperty(key, in: context)
  }

  func hasProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.hasProperty(key, in: context)
  }

  func propertyNames(in context: borrowing MockSurfaceInstantContext) -> [String] {
    delegate.propertyNames(in: context)
  }

  // MARK: Invocation

  func call(
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.call(arguments: arguments, in: context)
  }

  func call(
    this thisValue: borrowing CopyableSurfaceValue,
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.call(this: thisValue.delegate, arguments: arguments, in: context)
  }

  func call(
    this thisValue: borrowing MockSurfaceCallbackValue,
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.call(this: thisValue, arguments: arguments, in: context)
  }

  func construct(
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.construct(arguments: arguments, in: context)
  }

  func invokeMethod(
    _ name: StaticString,
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.invokeMethod(name, arguments: arguments, in: context)
  }

  func invokeMethod(
    _ name: borrowing MockSurfacePropertyStringKey,
    arguments: [MockSurfaceCallArgument],
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.invokeMethod(name, arguments: arguments, in: context)
  }

  // MARK: Object conversion and classification

  func toObject(
    in context: borrowing MockSurfaceInstantContext
  ) -> JSResult<MockSurfaceValue> {
    delegate.toObject(in: context)
  }

  func isArray(in context: borrowing MockSurfaceInstantContext) -> Bool {
    delegate.isArray(in: context)
  }

  func isDate(in context: borrowing MockSurfaceInstantContext) -> Bool {
    delegate.isDate(in: context)
  }

  func isInstanceOf(
    _ constructor: borrowing CopyableSurfaceValue,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.isInstanceOf(constructor.delegate, in: context)
  }

  func isArrayBuffer(in context: borrowing MockSurfaceInstantContext) -> Bool {
    delegate.isArrayBuffer(in: context)
  }

  func isTypedArray(in context: borrowing MockSurfaceInstantContext) -> Bool {
    delegate.isTypedArray(in: context)
  }

  // MARK: Callback-value parameters

  func setProperty(
    _ key: StaticString,
    to value: borrowing MockSurfaceCallbackValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.setProperty(key, to: value, attributes: attributes, in: context)
  }

  func setProperty(
    _ key: borrowing MockSurfacePropertyStringKey,
    to value: borrowing MockSurfaceCallbackValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.setProperty(key, to: value, attributes: attributes, in: context)
  }

  func isInstanceOf(
    _ constructor: borrowing MockSurfaceCallbackValue,
    in context: borrowing MockSurfaceInstantContext
  ) -> Bool {
    delegate.isInstanceOf(constructor, in: context)
  }
}

@Test func nonCopyableValueUsesPredicateDefaults() {
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "nonCopyableSurface"))
  let value = NonCopyableSurfaceValue(
    handle: MockValueHandle(rawValue: MockValue(kind: "string", payload: "hello")),
    context: context,
    storedType: .string
  )

  // The eight predicates come from `extension JSValue where Self: ~Copyable`
  // and derive from `type()`. `#expect` captures its subject, so calls on the
  // noncopyable value are evaluated first and only their Copyable results are
  // asserted.
  let type = value.type()
  #expect(type == .string)

  let isString = value.isString()
  let isUndefined = value.isUndefined()
  let isNull = value.isNull()
  let isBoolean = value.isBoolean()
  let isNumber = value.isNumber()
  let isSymbol = value.isSymbol()
  let isObject = value.isObject()
  let isBigInt = value.isBigInt()
  #expect(isString)
  #expect(!isUndefined)
  #expect(!isNull)
  #expect(!isBoolean)
  #expect(!isNumber)
  #expect(!isSymbol)
  #expect(!isObject)
  #expect(!isBigInt)

  let text = value.toString()
  let number = value.toNumber()
  let truth = value.toBoolean()
  #expect(text == "hello")
  #expect(number.isNaN)
  #expect(truth)

  let same = NonCopyableSurfaceValue(
    handle: MockValueHandle(rawValue: MockValue(kind: "string", payload: "hello")),
    context: context,
    storedType: .string
  )
  let strictlyEqual = value.strictlyEquals(same)
  let looselyEqual = value.looselyEquals(same)
  #expect(strictlyEqual)
  #expect(looselyEqual)
}

@Test func copyableValueKeepsTheSamePredicateDefaults() {
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "copyableSurface"))
  let original = CopyableSurfaceValue(
    handle: MockValueHandle(rawValue: MockValue(kind: "string", payload: "hello")),
    context: context,
    storedType: .string
  )
  let copy = original

  #expect(copy.isString())
  #expect(copy.toString() == "hello")
  #expect(copy.toBoolean())
  #expect(original.strictlyEquals(copy))
}

// MARK: - `#isolation` same-name overload (S5)
//
// Each engine value type implements the same-name overload taking
// `isolated Context = #isolation` (the requirement cannot carry a default
// argument). Its result is adopted onto the context default scope, so it
// outlives the synchronous call. `MockSurfaceValue` is the mock's real value
// type and the witness of that overload.

/// Isolated to the mock context actor, so the context argument of
/// `getProperty` defaults to `#isolation`. Nothing but the context handle
/// crosses isolation: the value is created on the actor.
private func isolatedMockPropertyKind(
  _ contextHandle: MockContextHandle,
  on _: isolated MockSurfaceContext
) -> String {
  let value = MockSurfaceValue(
    handle: MockValueHandle(rawValue: MockValue(kind: "object", payload: "isolation")),
    contextHandle: contextHandle
  )
  switch value.getProperty("name") {
  case .value(let result):
    return result.borrowHandle().rawValue.kind
  case .exception:
    return "<exception>"
  }
}

@Test func mockValueUsesIsolationOverload() async {
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "nonCopyableIsolation"))
  let actorContext = MockSurfaceContext(driverContextHandle: context)

  let kind = await isolatedMockPropertyKind(context, on: actorContext)
  #expect(kind == "property")
}

// MARK: - Encoder surface defaults (S7)
//
// `JSValueEncodable` implements only `toSurfaceValue`; the throwing
// counterpart must resolve through `extension JSValueEncodable where
// Self: ~Copyable`. A noncopyable conformer is the proof.

private struct NonCopyableSurfaceEncodable: JSValueEncodable, ~Copyable {
  let text: String

  func toSurfaceValue<C: JSValueScope & ~Copyable>(
    in context: borrowing C
  ) -> C.Value {
    context.persist(context.makeString(text))
  }
}

@Test func nonCopyableEncodableUsesProtocolDefaults() {
  let runtime = MockEngine.makeRuntimeHandle()
  guard let context = MockEngine.makeBorrowedContextHandleFromRuntime(in: runtime) else {
    Issue.record("MockEngine could not create a context handle")
    return
  }
  let scope = MockSurfaceInstantContext(handle: context)

  let encodable = NonCopyableSurfaceEncodable(text: "noncopyable")
  let encoded = try? encodable.tryEncodeSurface(in: scope)
  let encodedText = encoded?.toString() ?? "<nil>"
  #expect(encodedText.hasSuffix("noncopyable"))

  let nonThrowing = encodable.toSurfaceValue(in: scope)
  let nonThrowingText = nonThrowing.toString()
  #expect(nonThrowingText.hasSuffix("noncopyable"))
}
