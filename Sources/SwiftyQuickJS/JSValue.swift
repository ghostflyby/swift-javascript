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

  public init(_ value: borrowing QJSCallbackValue) {
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
/// Base classification, conversion, and equality route directly to the
/// `QJSEngine` statics over the raw value and context.
public struct QJSValue: SwiftJavaScript.JSValue, ~Copyable {
  public typealias Context = QJSContext
  public typealias InstantContext = QJSInstantContext

  package let value: CQuickJSValue
  package let contextRef: OpaquePointer

  package init(value: CQuickJSValue, contextRef: OpaquePointer) {
    self.value = value
    self.contextRef = contextRef
  }

  public func asCallArgument() -> QJSCallArgument {
    QJSCallArgument(value: value)
  }

  // MARK: - Classification and conversion

  public func type() -> JSType {
    guard let valueType = QJSEngine.valueType(value) else {
      preconditionFailure("QJSValue.type() could not query value type")
    }
    return valueType
  }

  public func toString() -> String {
    QJSEngine.toString(value, in: contextRef) ?? ""
  }

  public func toNumber() -> Double {
    QJSEngine.toNumber(value, in: contextRef)
  }

  public func toBoolean() -> Bool {
    QJSEngine.toBoolean(value, in: contextRef)
  }

  // MARK: - Equality

  public func looselyEquals(_ other: borrowing QJSValue) -> Bool {
    QJSEngine.looselyEquals(value, other.value, in: contextRef) ?? false
  }

  public func strictlyEquals(_ other: borrowing QJSValue) -> Bool {
    QJSEngine.strictlyEquals(value, other.value, in: contextRef) ?? false
  }
}

extension QJSContext {
  public typealias CallArgument = QJSCallArgument
}

extension QJSCallbackValue {
  public func asCallArgument() -> QJSCallArgument {
    QJSCallArgument(value: value)
  }
}
