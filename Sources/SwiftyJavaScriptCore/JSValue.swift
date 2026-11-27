import JavaScriptCore
import SwiftJavaScript

/// The JavaScriptCore call-argument token.
///
/// Value views are `~Copyable`, so arguments travel as this `Copyable` token
/// instead. It borrows the value handle: keep the source value's arena alive
/// and use the token only for the immediate synchronous call it is passed to.
public struct JSCCallArgument: SwiftJavaScript.JSCallArgument {
  package let ref: JSValueRef

  public init(_ value: borrowing JSCValue) {
    self.ref = value.ref
  }

  package init(ref: JSValueRef) {
    self.ref = ref
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
/// `JSCEngine` statics over the raw `JSValueRef` and `JSGlobalContextRef`;
/// the property/invocation/typed-array surface is added by S5.
public struct JSCValue: SwiftJavaScript.JSValue, ~Copyable {
  public typealias Context = JSCContext
  public typealias InstantContext = JSCInstantContext

  package let ref: JSValueRef
  package let contextRef: JSGlobalContextRef

  package init(ref: JSValueRef, contextRef: JSGlobalContextRef) {
    self.ref = ref
    self.contextRef = contextRef
  }

  public func asCallArgument() -> JSCCallArgument {
    JSCCallArgument(ref: ref)
  }

  // MARK: - Classification and conversion

  public func type() -> SwiftJavaScript.JSType {
    guard let valueType = javaScriptCoreValueTypeForHandle(ref, in: contextRef) else {
      preconditionFailure("JSCValue.type() could not query value type")
    }
    return valueType
  }

  public func toString() -> String {
    javaScriptCoreToStringForHandle(ref, in: contextRef) ?? ""
  }

  public func toNumber() -> Double {
    javaScriptCoreToNumberForHandle(ref, in: contextRef)
  }

  public func toBoolean() -> Bool {
    javaScriptCoreToBooleanForHandle(ref, in: contextRef)
  }

  // MARK: - Equality

  public func looselyEquals(_ other: borrowing JSCValue) -> Bool {
    javaScriptCoreLooselyEqualsHandle(ref, other.ref, in: contextRef) ?? false
  }

  public func strictlyEquals(_ other: borrowing JSCValue) -> Bool {
    javaScriptCoreStrictlyEqualsHandle(ref, other.ref, in: contextRef) ?? false
  }
}

extension JSCContext {
  public typealias CallArgument = JSCCallArgument
}
