import SwiftJavaScript
import Testing

// MARK: - `JSValue` default implementations for `~Copyable` conformers (S4)
//
// The base predicates/conversions/equality live in
// `extension JSValue where Self: ~Copyable`. These conformers implement only
// `type()` and borrow the rest, which is what proves the extension is
// reachable from a noncopyable value. The Copyable conformer is the control:
// the same defaults must remain available without `~Copyable`.

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
}

@Test func nonCopyableValueUsesProtocolDefaults() {
  let context = MockContextHandle(rawContext: MockContext(runtimeID: "nonCopyableSurface"))
  let value = NonCopyableSurfaceValue(
    handle: MockValueHandle(rawValue: MockValue(kind: "string", payload: "hello")),
    context: context,
    storedType: .string
  )

  // `#expect` captures its subject, so calls on the noncopyable value are
  // evaluated first and only their Copyable results are asserted.
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

@Test func copyableValueKeepsTheSameDefaults() {
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
// The S5 operations add a requirement taking `borrowing InstantContext`
// and a same-name overload taking `isolated Context = #isolation`. A
// noncopyable conformer that implements neither still compiles and runs: the
// requirement resolves to the core sync default and `value.getProperty("name")`
// resolves to the isolation overload.

/// Isolated to the mock context actor, so the context argument of
/// `getProperty` defaults to `#isolation`. Nothing but the context handle
/// crosses isolation: the value and its window are created on the actor.
private func isolatedMockPropertyKind(
  _ contextHandle: MockContextHandle,
  on _: isolated MockSurfaceContext
) -> String {
  let scope = MockSurfaceInstantContext(handle: contextHandle)
  let value = NonCopyableSurfaceValue(
    handle: MockValueHandle(rawValue: MockValue(kind: "object", payload: "isolation")),
    context: contextHandle,
    storedType: .object
  )
  switch value.getProperty("name") {
  case .value(let result):
    return result.borrowHandle().rawValue.kind
  case .exception:
    return "<exception>"
  }
}

@Test func nonCopyableValueUsesIsolationDefaultOverload() async {
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
