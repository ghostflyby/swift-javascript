import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

/// The QuickJS class wrapper (S11).
///
/// A concrete `final class` over one `JSClassID` of one runtime. QuickJS
/// classes are owned by their runtime and have no reference count of their
/// own, so there is no retain/release pair here. `retainedOwner` keeps the
/// Swift class record (definition + exotic method table) alive for the
/// wrapper's lifetime.
public final class QJSClass: SwiftJavaScript.JSClass, @unchecked Sendable {
  public typealias Context = QJSContext

  package let classID: JSClassID
  /// `nil` for a class not yet bound to a runtime.
  package let runtimeRef: OpaquePointer?
  package let retainedOwner: AnyObject?

  package init(
    classID: JSClassID,
    runtimeRef: OpaquePointer?,
    retainedOwner: AnyObject? = nil
  ) {
    self.classID = classID
    self.runtimeRef = runtimeRef
    self.retainedOwner = retainedOwner
  }
}

extension QJSClass: Equatable {
  public static func == (lhs: QJSClass, rhs: QJSClass) -> Bool {
    lhs.classID == rhs.classID && lhs.runtimeRef == rhs.runtimeRef
  }
}

extension QJSClass: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(classID)
    hasher.combine(runtimeRef)
  }
}
