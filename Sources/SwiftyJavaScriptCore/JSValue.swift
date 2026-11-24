import SwiftJavaScript

/// The JavaScriptCore user-facing value view (S4).
///
/// `JSCValue` is a local value in the V8 `Local<T>` sense: it stores the
/// engine value handle and the context handle it was created under (both
/// Copyable identity tokens) and carries **no ownership**. The JavaScriptCore
/// reference is GC-managed and rooted by the scope arena the value was adopted
/// or anchored in, so copying a view is pure identity and dropping it performs
/// no release.
///
/// Base classification, conversion, and equality route directly to the
/// `JSCContextHandle` driver; the property/invocation/typed-array surface is
/// added by S5.
public struct JSCValue: SwiftJavaScript.JSValue, ~Copyable {
  public typealias ContextHandle = JSCContextHandle
  public typealias ValueHandle = JSCValueHandle
  public typealias Context = JSCContext
  public typealias InstantContext = JSCInstantContext

  package let handle: JSCValueHandle
  public let contextHandle: JSCContextHandle

  package init(handle: JSCValueHandle, contextHandle: JSCContextHandle) {
    self.handle = handle
    self.contextHandle = contextHandle
  }

  public borrowing func borrowHandle() -> JSCValueHandle {
    handle
  }

  // MARK: - Classification and conversion

  public func type() -> JSType {
    guard let valueType = contextHandle.valueTypeForHandle(handle) else {
      preconditionFailure("JSCValue.type() could not query value type")
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

  public func looselyEquals(_ other: borrowing JSCValue) -> Bool {
    contextHandle.looselyEqualsHandle(handle, other.borrowHandle()) ?? false
  }

  public func strictlyEquals(_ other: borrowing JSCValue) -> Bool {
    contextHandle.strictlyEqualsHandle(handle, other.borrowHandle()) ?? false
  }
}
