import SwiftJavaScript

/// A persistent, Sendable identity for a QuickJS value bound in a
/// context-side registry.
///
/// QuickJS counterpart of `JSCPersistentHandle`: public identity plus a weak
/// view of the registry. Settlement is reference-counted (`JS_FreeValue`), so
/// the payload is settled on the VM thread by the registry exactly once.
public final class QJSPersistentHandle: SwiftJavaScript.JSPersistentHandle, Sendable {
  public let identity: JSPersistentHandleIdentity

  private let registryReference: PersistentRegistryReference<QJSContextHandle>

  package init(
    identity: JSPersistentHandleIdentity,
    registry: JSPersistentHandleRegistry<QJSContextHandle>
  ) {
    self.identity = identity
    self.registryReference = PersistentRegistryReference(registry)
  }

  @discardableResult
  public func invalidate() -> Bool {
    registryReference.value?.release(identity) ?? false
  }

  deinit {
    _ = registryReference.value?.release(identity)
  }

  public static func == (lhs: QJSPersistentHandle, rhs: QJSPersistentHandle) -> Bool {
    lhs.identity == rhs.identity
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identity)
  }
}
