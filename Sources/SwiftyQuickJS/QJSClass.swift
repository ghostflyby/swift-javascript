import SwiftJavaScript

/// The QuickJS class wrapper (S11).
///
/// A concrete `final class` over one `QJSClassHandle`. QuickJS classes are
/// owned by their runtime and have no reference count of their own, so
/// `retainReference`/`releaseReference` on the handle are explicit no-ops; the
/// wrapper still performs one retain/release pair so the lifecycle ledger reads
/// the same as the JavaScriptCore side. `retainedOwner` keeps the Swift class
/// record (definition + exotic method table) alive for the wrapper's lifetime.
public final class QJSClass: SwiftJavaScript.JSClass, @unchecked Sendable {
  public typealias Context = QJSContext

  package let handle: QJSClassHandle
  package let retainedOwner: AnyObject?

  package init(handleClass: QJSClassHandle, retainedOwner: AnyObject? = nil) {
    self.handle = handleClass
    self.retainedOwner = retainedOwner
    _ = handleClass.retainReference()
  }

  package init(adoptingHandleClass: QJSClassHandle, retainedOwner: AnyObject? = nil) {
    self.handle = adoptingHandleClass
    self.retainedOwner = retainedOwner
  }

  deinit {
    _ = handle.releaseReference()
  }
}

extension QJSClass: Equatable {
  public static func == (lhs: QJSClass, rhs: QJSClass) -> Bool {
    lhs.handle == rhs.handle
  }
}

extension QJSClass: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(handle)
  }
}
