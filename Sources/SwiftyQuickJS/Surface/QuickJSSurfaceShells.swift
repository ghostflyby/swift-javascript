import SwiftJavaScript

// MARK: - Callback views and argument views
//
// `QJSValue` is the value view (`JSValue.swift`); the types below are the
// callback-exit and argument views. Each type names only the members its
// protocol needs: its context, and the rest as aliases of that context's. The
// scopes are the real structs in `QuickJSScopes.swift`; `Class` is the real
// `QJSClass` (`QJSClass.swift`).

public struct QJSCallbackValue: SwiftJavaScript.JSCallbackValue, ~Copyable {
  public typealias Context = QJSContext

  package let handle: QJSValueHandle
  package let contextHandle: QJSContextHandle

  package init(handle: QJSValueHandle, contextHandle: QJSContextHandle) {
    self.handle = handle
    self.contextHandle = contextHandle
  }

  package borrowing func borrowHandle() -> QJSValueHandle {
    handle
  }

  @available(*, noasync)
  public func type() -> JSType {
    guard let valueType = contextHandle.valueTypeForHandle(handle) else {
      preconditionFailure("QJSCallbackValue.type() could not query value type")
    }
    return valueType
  }

  // MARK: - Conversion and equality
  //
  // The callback window's views are `noasync` on the concrete type: they only
  // exist inside a synchronous callback window.

  @available(*, noasync)
  public func toString() -> String {
    contextHandle.toStringForHandle(handle) ?? ""
  }

  @available(*, noasync)
  public func toNumber() -> Double {
    contextHandle.toNumberForHandle(handle)
  }

  @available(*, noasync)
  public func toBoolean() -> Bool {
    contextHandle.toBooleanForHandle(handle)
  }

  @available(*, noasync)
  public func looselyEquals(_ other: borrowing QJSCallbackValue) -> Bool {
    contextHandle.looselyEqualsHandle(handle, other.borrowHandle()) ?? false
  }

  @available(*, noasync)
  public func strictlyEquals(_ other: borrowing QJSCallbackValue) -> Bool {
    contextHandle.strictlyEqualsHandle(handle, other.borrowHandle()) ?? false
  }
}

public struct QJSCallbackReturn: SwiftJavaScript.JSCallbackReturn, ~Copyable {
  public typealias Context = QJSContext

  /// The borrowed engine handle carried by this handoff. Package-internal:
  /// the trampoline and the same-package tests are the only readers.
  package let handle: QJSValueHandle
  public let isException: Bool

  /// A value created in the callback window and anchored by its arena.
  package init(temporary handle: QJSValueHandle) {
    self.handle = handle
    self.isException = false
  }

  /// A value promoted to the context default scope (or otherwise arena-owned
  /// beyond the callback window).
  package init(persistent value: borrowing QJSValue) {
    self.handle = value.borrowHandle()
    self.isException = false
  }

  /// A thrown value. The trampoline duplicates before handing it to
  /// `JS_Throw`; the owning arena settles its own reference at drain.
  package init(exception handle: QJSValueHandle) {
    self.handle = handle
    self.isException = true
  }

  package borrowing func borrowHandle() -> QJSValueHandle {
    handle
  }
}

// MARK: - Arguments

public struct QJSArguments: SwiftJavaScript.JSArguments, ~Copyable {
  public typealias Context = QJSContext
  public typealias Value = QJSValue
  public typealias InstantContext = QJSInstantContext

  public let count: Int
  package let borrowedValueHandleAt: (Int, QJSContextHandle) -> QJSValueHandle?

  package init(
    count: Int,
    borrowedValueHandleAt: @escaping (Int, QJSContextHandle) -> QJSValueHandle?
  ) {
    self.count = count
    self.borrowedValueHandleAt = borrowedValueHandleAt
  }

  public func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing QJSInstantContext,
    _ body: (borrowing QJSValue) -> R
  ) -> R {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let handle = borrowedValueHandleAt(index, context.driverContextHandle) else {
      fatalError("JSArgument handle is unavailable")
    }
    return body(
      QJSValue(handle: handle, contextHandle: context.driverContextHandle))
  }
}

public struct QJSCallbackArguments: SwiftJavaScript.JSCallbackArguments, ~Copyable {
  public typealias Context = QJSContext
  public typealias Value = QJSCallbackValue
  public typealias InstantContext = QJSInstantContext

  public let count: Int
  package let borrowedValueHandleAt: (Int) -> QJSValueHandle?

  package init(
    count: Int,
    borrowedValueHandleAt: @escaping (Int) -> QJSValueHandle?
  ) {
    self.count = count
    self.borrowedValueHandleAt = borrowedValueHandleAt
  }

  @available(*, noasync)
  public func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing QJSInstantContext,
    _ body: (borrowing QJSCallbackValue) -> R
  ) -> R {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let handle = borrowedValueHandleAt(index) else {
      fatalError("JSArgument handle is unavailable")
    }
    return body(
      QJSCallbackValue(handle: handle, contextHandle: context.driverContextHandle))
  }

  @available(*, noasync)
  public func withThrowingValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing QJSInstantContext,
    _ body: (borrowing QJSCallbackValue) throws(JSValueConversionError) -> R
  ) throws(JSValueConversionError) -> R {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let handle = borrowedValueHandleAt(index) else {
      fatalError("JSArgument handle is unavailable")
    }
    return try body(
      QJSCallbackValue(handle: handle, contextHandle: context.driverContextHandle))
  }
}

// MARK: - Scopes
//
// The real scope types live in `QuickJSScopes.swift` (S7). The argument views
// above already address them.

// MARK: - Persistent handles and self-owning inputs
//
// The real types live in `QJSPersistentHandle.swift` and
// `QJSPreparedInputs.swift`.

// MARK: - Buffers
//
// The real types live in `QJSArrayBuffer.swift`.
