import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

/// The QuickJS call-argument token.
///
/// Value views are `~Copyable`, so arguments travel as this `Copyable` token
/// instead. It borrows the value: keep the source value's arena alive and use
/// the token only for the immediate synchronous call it is passed to. QuickJS
/// is reference-counted, so a stored token does not retain the value.
public struct QJSCallArgument: SwiftJavaScript.JSCallArgument {
  package let value: CQuickJSValue

  public init(_ value: borrowing QJSValue) {
    self.value = value.value
  }

  package init(value: CQuickJSValue) {
    self.value = value
  }
}

/// The QuickJS user-facing value view (S4).
///
/// A non-owning identity view over one `CQuickJSValue` and the raw context it
/// is addressed through. QuickJS is reference-counted, so the creation
/// reference is owned by the scope arena that adopted or anchored the value;
/// this view owns nothing and its `deinit` releases nothing.
///
/// QuickJS encodes undefined, null, booleans, integers and doubles as
/// immediate values: creating and comparing them does not touch a runtime.
/// The context-free initializers therefore produce values with no context
/// (`contextRef == nil`); operations that need an engine context take one
/// explicitly, and the value-level conversions fall back to their ECMAScript
/// meanings for immediates.
///
/// Context-bound classification, conversion, and equality route to the
/// `QuickJS` statics; immediate values use tag-level paths that need no
/// context.
public struct QJSValue: SwiftJavaScript.JSValue, ~Copyable, ~Escapable {
  public typealias Context = QJSContext
  public typealias InstantContext = QJSInstantContext

  package let value: CQuickJSValue
  /// The context this view was created under; `nil` for a context-free
  /// immediate value.
  package let contextRef: OpaquePointer?

  @_lifetime(borrow contextRef)
  package init(value: CQuickJSValue, contextRef: OpaquePointer?) {
    self.value = value
    self.contextRef = contextRef
  }

  @_lifetime(borrow context)
  package init(value: CQuickJSValue, in context: borrowing QJSInstantContext) {
    self.value = value
    self.contextRef = context.contextRef
  }

  /// The context an engine operation must run under. Values created through a
  /// scope always carry one; only context-free immediates may lack it, and
  /// they never reach an operation that requires a context.
  package var requiredContextRef: OpaquePointer {
    guard let contextRef else {
      preconditionFailure("QJSValue operation requires an engine context")
    }
    return contextRef
  }

  public func asCallArgument() -> QJSCallArgument {
    QJSCallArgument(value: value)
  }

  // MARK: - Classification and conversion

  public func type() -> JSType {
    guard let valueType = quickJSValueType(value) else {
      preconditionFailure("QJSValue.type() could not query value type")
    }
    return valueType
  }

  public func toString() -> String {
    if let contextRef {
      return quickJSToString(value, in: contextRef) ?? ""
    }
    guard let text = quickJSImmediateToString(value) else {
      preconditionFailure("QJSValue.toString() requires an engine context")
    }
    return text
  }

  public func toNumber() -> Double {
    if let contextRef {
      return quickJSToNumber(value, in: contextRef)
    }
    guard let number = quickJSImmediateToNumber(value) else {
      preconditionFailure("QJSValue.toNumber() requires an engine context")
    }
    return number
  }

  public func toBoolean() -> Bool {
    if let contextRef {
      return quickJSToBoolean(value, in: contextRef)
    }
    guard let truth = quickJSImmediateToBoolean(value) else {
      preconditionFailure("QJSValue.toBoolean() requires an engine context")
    }
    return truth
  }

  // MARK: - Context-free classification
  //
  // QuickJS answers these from the value's class/tag alone, so they are
  // available without a context window.

  public func isArray() -> Bool {
    quickJSIsArray(value)
  }

  public func isArrayBuffer() -> Bool {
    quickJSIsArrayBuffer(value)
  }

  public func isTypedArray() -> Bool {
    quickJSTypedArrayKind(value) != nil
  }

  // MARK: - Equality

  public func looselyEquals(_ other: borrowing QJSValue) -> Bool {
    if let contextRef = contextRef ?? other.contextRef {
      return quickJSLooselyEquals(value, other.value, in: contextRef) ?? false
    }
    guard let result = quickJSImmediateLooselyEquals(value, other.value) else {
      preconditionFailure("QJSValue.looselyEquals requires an engine context")
    }
    return result
  }

  public func strictlyEquals(_ other: borrowing QJSValue) -> Bool {
    if let contextRef = contextRef ?? other.contextRef {
      return quickJSStrictlyEquals(value, other.value, in: contextRef) ?? false
    }
    guard let result = quickJSImmediateStrictlyEquals(value, other.value) else {
      preconditionFailure("QJSValue.strictlyEquals requires an engine context")
    }
    return result
  }
}

extension QJSContext {
  public typealias CallArgument = QJSCallArgument
}
