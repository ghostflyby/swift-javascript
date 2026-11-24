import SwiftJavaScript

// MARK: - Callback views and argument views
//
// `JSCValue` is the value view (`JSValue.swift`); the types below are the
// callback-exit and argument views. Each type names only the members its
// protocol needs: its context, and the rest as aliases of that context's.
public struct JSCCallbackValue: SwiftJavaScript.JSCallbackValue, ~Copyable {
  public typealias Context = JSCContext
  public typealias ContextHandle = JSCContextHandle
  public typealias ValueHandle = JSCValueHandle

  package let handle: JSCValueHandle
  public let contextHandle: JSCContextHandle

  package init(handle: JSCValueHandle, contextHandle: JSCContextHandle) {
    self.handle = handle
    self.contextHandle = contextHandle
  }

  public borrowing func borrowHandle() -> JSCValueHandle {
    handle
  }

  @available(*, noasync)
  public func type() -> JSType {
    guard let valueType = contextHandle.valueTypeForHandle(handle) else {
      preconditionFailure("JSCCallbackValue.type() could not query value type")
    }
    return valueType
  }
}

public struct JSCCallbackReturn: SwiftJavaScript.JSCallbackReturn, ~Copyable {
  public typealias Context = JSCContext
  public typealias ValueHandle = JSCValueHandle

  package let handle: JSCValueHandle
  /// Semantic marker only: trampolines hand the engine its own reference for
  /// every state and branch on this flag solely to choose `throw` vs return.
  public let isException: Bool

  /// A value created in the callback window and anchored by its arena.
  package init(temporary handle: JSCValueHandle) {
    self.handle = handle
    self.isException = false
  }

  /// A value promoted to the context default scope (or otherwise arena-owned
  /// beyond the callback window).
  package init(persistent value: borrowing JSCValue) {
    self.handle = value.borrowHandle()
    self.isException = false
  }

  /// A thrown value. The trampoline hands the engine its own reference; the
  /// owning arena settles its reference at drain.
  package init(exception handle: JSCValueHandle) {
    self.handle = handle
    self.isException = true
  }

  public borrowing func borrowHandle() -> JSCValueHandle {
    handle
  }
}

// MARK: - Arguments

public struct JSCArguments: SwiftJavaScript.JSArguments, ~Copyable {
  public typealias Context = JSCContext
  public typealias Value = JSCValue
  public typealias InstantContext = JSCInstantContext

  public let count: Int
  package let borrowedValueHandleAt: (Int, JSCContextHandle) -> JSCValueHandle?

  package init(
    count: Int,
    borrowedValueHandleAt: @escaping (Int, JSCContextHandle) -> JSCValueHandle?
  ) {
    self.count = count
    self.borrowedValueHandleAt = borrowedValueHandleAt
  }

  public func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing JSCInstantContext,
    _ body: (borrowing JSCValue) -> R
  ) -> R {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let handle = borrowedValueHandleAt(index, context.driverContextHandle) else {
      fatalError("JSArgument handle is unavailable")
    }
    return body(
      JSCValue(handle: handle, contextHandle: context.driverContextHandle))
  }
}

public struct JSCCallbackArguments: SwiftJavaScript.JSCallbackArguments, ~Copyable {
  public typealias Context = JSCContext
  public typealias Value = JSCCallbackValue
  public typealias InstantContext = JSCInstantContext

  public let count: Int
  package let borrowedValueHandleAt: (Int) -> JSCValueHandle?

  package init(
    count: Int,
    borrowedValueHandleAt: @escaping (Int) -> JSCValueHandle?
  ) {
    self.count = count
    self.borrowedValueHandleAt = borrowedValueHandleAt
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
    guard let handle = borrowedValueHandleAt(index) else {
      fatalError("JSArgument handle is unavailable")
    }
    return body(
      JSCCallbackValue(handle: handle, contextHandle: context.driverContextHandle))
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
    guard let handle = borrowedValueHandleAt(index) else {
      fatalError("JSArgument handle is unavailable")
    }
    return try body(
      JSCCallbackValue(handle: handle, contextHandle: context.driverContextHandle))
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
