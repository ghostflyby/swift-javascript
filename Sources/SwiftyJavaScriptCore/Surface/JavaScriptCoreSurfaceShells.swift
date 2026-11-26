import JavaScriptCore
import SwiftJavaScript

// MARK: - Callback views and argument views
//
// `JSCValue` is the value view (`JSValue.swift`); the types below are the
// callback-exit and argument views. Each type names only the members its
// protocol needs: its context, and the rest as aliases of that context's.
public struct JSCCallbackValue: SwiftJavaScript.JSCallbackValue, ~Copyable {
  public typealias Context = JSCContext

  package let ref: JSValueRef
  package let contextRef: JSGlobalContextRef

  package init(ref: JSValueRef, contextRef: JSGlobalContextRef) {
    self.ref = ref
    self.contextRef = contextRef
  }

  @available(*, noasync)
  public func type() -> SwiftJavaScript.JSType {
    guard let valueType = JSCEngine.valueTypeForHandle(ref, in: contextRef) else {
      preconditionFailure("JSCCallbackValue.type() could not query value type")
    }
    return valueType
  }

  // MARK: - Conversion and equality
  //
  // The callback window's views are `noasync` on the concrete type: they only
  // exist inside a synchronous callback window.

  @available(*, noasync)
  public func toString() -> String {
    JSCEngine.toStringForHandle(ref, in: contextRef) ?? ""
  }

  @available(*, noasync)
  public func toNumber() -> Double {
    JSCEngine.toNumberForHandle(ref, in: contextRef)
  }

  @available(*, noasync)
  public func toBoolean() -> Bool {
    JSCEngine.toBooleanForHandle(ref, in: contextRef)
  }

  @available(*, noasync)
  public func looselyEquals(_ other: borrowing JSCCallbackValue) -> Bool {
    JSCEngine.looselyEqualsHandle(ref, other.ref, in: contextRef) ?? false
  }

  @available(*, noasync)
  public func strictlyEquals(_ other: borrowing JSCCallbackValue) -> Bool {
    JSCEngine.strictlyEqualsHandle(ref, other.ref, in: contextRef) ?? false
  }
}

public struct JSCCallbackReturn: SwiftJavaScript.JSCallbackReturn, ~Copyable {
  public typealias Context = JSCContext

  /// The borrowed engine reference carried by this handoff. Package-internal:
  /// the trampolines and the same-package tests are the only readers.
  package let ref: JSValueRef
  /// Semantic marker only: trampolines hand the engine its own reference for
  /// every state and branch on this flag solely to choose `throw` vs return.
  public let isException: Bool

  /// A value created in the callback window and anchored by its arena.
  package init(temporary ref: JSValueRef) {
    self.ref = ref
    self.isException = false
  }

  /// A value promoted to the context default scope (or otherwise arena-owned
  /// beyond the callback window).
  package init(persistent value: borrowing JSCValue) {
    self.ref = value.ref
    self.isException = false
  }

  /// A thrown value. The trampoline hands the engine its own reference; the
  /// owning arena settles its reference at drain.
  package init(exception ref: JSValueRef) {
    self.ref = ref
    self.isException = true
  }
}

// MARK: - Arguments

public struct JSCArguments: SwiftJavaScript.JSArguments, ~Copyable {
  public typealias Context = JSCContext
  public typealias Value = JSCValue
  public typealias InstantContext = JSCInstantContext

  public let count: Int
  package let borrowedValueRefAt: (Int, JSGlobalContextRef) -> JSValueRef?

  package init(
    count: Int,
    borrowedValueRefAt: @escaping (Int, JSGlobalContextRef) -> JSValueRef?
  ) {
    self.count = count
    self.borrowedValueRefAt = borrowedValueRefAt
  }

  public func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing JSCInstantContext,
    _ body: (borrowing JSCValue) -> R
  ) -> R {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let ref = borrowedValueRefAt(index, context.contextRef) else {
      fatalError("JSArgument handle is unavailable")
    }
    return body(JSCValue(ref: ref, contextRef: context.contextRef))
  }
}

public struct JSCCallbackArguments: SwiftJavaScript.JSCallbackArguments, ~Copyable {
  public typealias Context = JSCContext
  public typealias Value = JSCCallbackValue
  public typealias InstantContext = JSCInstantContext

  public let count: Int
  package let borrowedValueRefAt: (Int) -> JSValueRef?

  package init(
    count: Int,
    borrowedValueRefAt: @escaping (Int) -> JSValueRef?
  ) {
    self.count = count
    self.borrowedValueRefAt = borrowedValueRefAt
  }

  @available(*, noasync)
  public func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing JSCInstantContext,
    _ body: (borrowing JSCCallbackValue) -> R
  ) -> R {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let ref = borrowedValueRefAt(index) else {
      fatalError("JSArgument handle is unavailable")
    }
    return body(JSCCallbackValue(ref: ref, contextRef: context.contextRef))
  }

  @available(*, noasync)
  public func withThrowingValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing JSCInstantContext,
    _ body: (borrowing JSCCallbackValue) throws(JSValueConversionError) -> R
  ) throws(JSValueConversionError) -> R {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let ref = borrowedValueRefAt(index) else {
      fatalError("JSArgument handle is unavailable")
    }
    return try body(JSCCallbackValue(ref: ref, contextRef: context.contextRef))
  }
}

// MARK: - Scopes
//
// The real scope types live in `JavaScriptCoreScopes.swift` (S7). The
// argument views above already address them.

// MARK: - Persistent handles and self-owning inputs
//
// The real types live in `JSCPersistentHandle.swift` and
// `JSCPreparedInputs.swift` (S9).

// MARK: - Buffers
//
// The real types live in `JSCArrayBuffer.swift` (S10).
