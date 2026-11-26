import SwiftJavaScript

/// The JavaScriptCore call-argument token.
///
/// Value views are `~Copyable`, so arguments travel as this `Copyable` token
/// instead. It borrows the value handle: keep the source value's arena alive
/// and use the token only for the immediate synchronous call it is passed to.
public struct JSCCallArgument: SwiftJavaScript.JSCallArgument {
  package let handle: JSCValueHandle

  public init(_ value: borrowing JSCValue) {
    self.handle = value.handle
  }

  public init(_ value: borrowing JSCCallbackValue) {
    self.handle = value.handle
  }

  package init(handle: JSCValueHandle) {
    self.handle = handle
  }
}

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
  package typealias ContextHandle = JSCContextHandle
  package typealias ValueHandle = JSCValueHandle
  public typealias Context = JSCContext
  public typealias InstantContext = JSCInstantContext

  package let handle: JSCValueHandle
  package let contextHandle: JSCContextHandle

  package init(handle: JSCValueHandle, contextHandle: JSCContextHandle) {
    self.handle = handle
    self.contextHandle = contextHandle
  }

  package borrowing func borrowHandle() -> JSCValueHandle {
    handle
  }

  public func asCallArgument() -> JSCCallArgument {
    JSCCallArgument(handle: handle)
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

extension JSCContext {
  public typealias CallArgument = JSCCallArgument
}

extension JSCCallbackValue {
  public func asCallArgument() -> JSCCallArgument {
    JSCCallArgument(handle: handle)
  }
}
