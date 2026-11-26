import SwiftJavaScript

/// A persistent, Sendable identity for a QuickJS value bound in a
/// context-side binding table.
///
/// QuickJS counterpart of `JSCPersistentHandle`: public identity plus a weak
/// view of the table. Settlement is reference-counted (`JS_FreeValue`), so the
/// payload is settled on the VM thread exactly once.
public final class QJSPersistentHandle: SwiftJavaScript.JSPersistentHandle, Sendable {
  public let identity: JSPersistentHandleIdentity

  private let bindingsReference: QJSPersistentBindingsReference

  init(
    identity: JSPersistentHandleIdentity,
    registry: QJSPersistentBindings
  ) {
    self.identity = identity
    self.bindingsReference = QJSPersistentBindingsReference(registry)
  }

  @discardableResult
  public func invalidate() -> Bool {
    bindingsReference.bindings?.release(identity) ?? false
  }

  deinit {
    _ = bindingsReference.bindings?.release(identity)
  }

  public static func == (lhs: QJSPersistentHandle, rhs: QJSPersistentHandle) -> Bool {
    lhs.identity == rhs.identity
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identity)
  }
}
