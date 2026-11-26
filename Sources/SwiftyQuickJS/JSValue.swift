import SwiftJavaScript

/// The QuickJS call-argument token.
///
/// Value views are `~Copyable`, so arguments travel as this `Copyable` token
/// instead. It borrows the value handle: keep the source value's arena alive
/// and use the token only for the immediate synchronous call it is passed to.
/// QuickJS is reference-counted, so a stored token does not retain the value.
public struct QJSCallArgument: SwiftJavaScript.JSCallArgument {
  package let handle: QJSValueHandle

  public init(_ value: borrowing QJSValue) {
    self.handle = value.handle
  }

  public init(_ value: borrowing QJSCallbackValue) {
    self.handle = value.handle
  }

  package init(handle: QJSValueHandle) {
    self.handle = handle
  }
}

/// The QuickJS user-facing value view (S4).
///
/// Mirrors `JSCValue`: a non-owning identity view over a `QJSValueHandle` and
/// the `QJSContextHandle` it is addressed through. QuickJS is
/// reference-counted, so the creation reference is owned by the scope arena
/// that adopted or anchored the handle; this view owns nothing and its
/// `deinit` releases nothing.
///
/// Base classification, conversion, and equality route directly to the
/// `QJSContextHandle` driver.
public struct QJSValue: SwiftJavaScript.JSValue, ~Copyable {
  package typealias ContextHandle = QJSContextHandle
  package typealias ValueHandle = QJSValueHandle
  public typealias Context = QJSContext
  public typealias InstantContext = QJSInstantContext

  package let handle: QJSValueHandle
  package let contextHandle: QJSContextHandle

  package init(handle: QJSValueHandle, contextHandle: QJSContextHandle) {
    self.handle = handle
    self.contextHandle = contextHandle
  }

  package borrowing func borrowHandle() -> QJSValueHandle {
    handle
  }

  public func asCallArgument() -> QJSCallArgument {
    QJSCallArgument(handle: handle)
  }

  // MARK: - Classification and conversion

  public func type() -> JSType {
    guard let valueType = contextHandle.valueTypeForHandle(handle) else {
      preconditionFailure("QJSValue.type() could not query value type")
    }
    return valueType
  }

  public func toString() -> String {
    contextHandle.toStringForHandle(handle) ?? ""
  }

  public func toNumber() -> Double {
    contextHandle.toNumberForHandle(handle)
  }

  public func toBoolean() -> Bool {
    contextHandle.toBooleanForHandle(handle)
  }

  // MARK: - Equality

  public func looselyEquals(_ other: borrowing QJSValue) -> Bool {
    contextHandle.looselyEqualsHandle(handle, other.borrowHandle()) ?? false
  }

  public func strictlyEquals(_ other: borrowing QJSValue) -> Bool {
    contextHandle.strictlyEqualsHandle(handle, other.borrowHandle()) ?? false
  }
}

extension QJSContext {
  public typealias CallArgument = QJSCallArgument
}

extension QJSCallbackValue {
  public func asCallArgument() -> QJSCallArgument {
    QJSCallArgument(handle: handle)
  }
}
