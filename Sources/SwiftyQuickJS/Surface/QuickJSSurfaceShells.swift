import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

// MARK: - Callback views and argument views
//
// `QJSValue` is the value view (`JSValue.swift`); the types below are the
// callback-exit and argument views. Each type names only the members its
// protocol needs: its context, and the rest as aliases of that context's. The
// scopes are the real structs in `QuickJSScopes.swift`; `Class` is the real
// `QJSClass` (`QJSClass.swift`).

public struct QJSCallbackValue: SwiftJavaScript.JSCallbackValue, ~Copyable {
  public typealias Context = QJSContext

  package let value: CQuickJSValue
  package let contextRef: OpaquePointer

  package init(value: CQuickJSValue, contextRef: OpaquePointer) {
    self.value = value
    self.contextRef = contextRef
  }

  @available(*, noasync)
  public func type() -> JSType {
    guard let valueType = QJSEngine.valueType(value) else {
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
    QJSEngine.toString(value, in: contextRef) ?? ""
  }

  @available(*, noasync)
  public func toNumber() -> Double {
    QJSEngine.toNumber(value, in: contextRef)
  }

  @available(*, noasync)
  public func toBoolean() -> Bool {
    QJSEngine.toBoolean(value, in: contextRef)
  }

  @available(*, noasync)
  public func looselyEquals(_ other: borrowing QJSCallbackValue) -> Bool {
    QJSEngine.looselyEquals(value, other.value, in: contextRef) ?? false
  }

  @available(*, noasync)
  public func strictlyEquals(_ other: borrowing QJSCallbackValue) -> Bool {
    QJSEngine.strictlyEquals(value, other.value, in: contextRef) ?? false
  }
}

public struct QJSCallbackReturn: SwiftJavaScript.JSCallbackReturn, ~Copyable {
  public typealias Context = QJSContext

  /// The borrowed engine value carried by this handoff. Package-internal: the
  /// trampoline and the same-package tests are the only readers.
  package let value: CQuickJSValue
  public let isException: Bool

  /// A value created in the callback window and anchored by its arena.
  package init(temporary value: CQuickJSValue) {
    self.value = value
    self.isException = false
  }

  /// A value promoted to the context default scope (or otherwise arena-owned
  /// beyond the callback window).
  package init(persistent value: borrowing QJSValue) {
    self.value = value.value
    self.isException = false
  }

  /// A thrown value. The trampoline duplicates before handing it to
  /// `JS_Throw`; the owning arena settles its own reference at drain.
  package init(exception value: CQuickJSValue) {
    self.value = value
    self.isException = true
  }
}

// MARK: - Arguments

public struct QJSArguments: SwiftJavaScript.JSArguments, ~Copyable {
  public typealias Context = QJSContext
  public typealias Value = QJSValue
  public typealias InstantContext = QJSInstantContext

  public let count: Int
  package let borrowedValueAt: (Int, OpaquePointer) -> CQuickJSValue?

  package init(
    count: Int,
    borrowedValueAt: @escaping (Int, OpaquePointer) -> CQuickJSValue?
  ) {
    self.count = count
    self.borrowedValueAt = borrowedValueAt
  }

  public func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing QJSInstantContext,
    _ body: (borrowing QJSValue) -> R
  ) -> R {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let value = borrowedValueAt(index, context.contextRef) else {
      fatalError("JSArgument value is unavailable")
    }
    return body(
      QJSValue(value: value, contextRef: context.contextRef))
  }
}

public struct QJSCallbackArguments: SwiftJavaScript.JSCallbackArguments, ~Copyable {
  public typealias Context = QJSContext
  public typealias Value = QJSCallbackValue
  public typealias InstantContext = QJSInstantContext

  public let count: Int
  package let borrowedValueAt: (Int) -> CQuickJSValue?

  package init(
    count: Int,
    borrowedValueAt: @escaping (Int) -> CQuickJSValue?
  ) {
    self.count = count
    self.borrowedValueAt = borrowedValueAt
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
    guard let value = borrowedValueAt(index) else {
      fatalError("JSArgument value is unavailable")
    }
    return body(
      QJSCallbackValue(value: value, contextRef: context.contextRef))
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
    guard let value = borrowedValueAt(index) else {
      fatalError("JSArgument value is unavailable")
    }
    return try body(
      QJSCallbackValue(value: value, contextRef: context.contextRef))
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
