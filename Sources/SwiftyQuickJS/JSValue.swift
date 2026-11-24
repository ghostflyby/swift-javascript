import SwiftJavaScript

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
  public typealias ContextHandle = QJSContextHandle
  public typealias ValueHandle = QJSValueHandle
  public typealias Context = QJSContext
  public typealias InstantContext = QJSInstantContext

  package let handle: QJSValueHandle
  public let contextHandle: QJSContextHandle

  package init(handle: QJSValueHandle, contextHandle: QJSContextHandle) {
    self.handle = handle
    self.contextHandle = contextHandle
  }

  public borrowing func borrowHandle() -> QJSValueHandle {
    handle
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
