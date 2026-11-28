import JavaScriptCore
import SwiftJavaScript

/// A persistent, Sendable identity for a JavaScriptCore value bound in a
/// context-side registry.
///
/// The registry keeps one rooted
/// engine reference and this object keeps only the binding's public identity
/// plus a weak view of the registry. The handle exposes no JavaScript
/// operation — resolving goes through `JSCContext`, `JSCInstantContext`, or
/// `JSCScope`, so the produced value enters the receiving frame's arena.
///
/// Lifecycle: minting claims and roots an independent
/// reference, copying the handle only bumps ARC, and the last owner's release
/// (or `invalidate()`) kills the identity immediately and settles the engine
/// reference through the context actor. Both the registry and the context are
/// weak, so a surviving handle cannot keep its context alive; the context's
/// teardown releases bindings it still owns.
public final class JSCPersistentHandle: SwiftJavaScript.JSPersistentHandle, Sendable {
  public let identity: JSPersistentHandleIdentity

  /// Weak by design (§2.6 in `docs/PERSISTENT_HANDLE_DESIGN.md`): keeping the
  /// registry alive from a handle would keep the whole context alive and make
  /// "container death yields nil" unreachable.
  private let registryReference: JSCPersistentBindingsReference

  /// Weak for the same reason: a surviving handle must not keep the context
  /// alive. A dead context already released its bindings at teardown.
  private let contextReference: JSCContextReference

  init(
    identity: JSPersistentHandleIdentity,
    registry: JSCPersistentBindings,
    context: JSCContext
  ) {
    self.identity = identity
    self.registryReference = JSCPersistentBindingsReference(registry)
    self.contextReference = JSCContextReference(context)
  }

  @discardableResult
  public func invalidate() -> Bool {
    guard let context = contextReference.value,
      let ref = registryReference.bindings?.take(identity)
    else {
      return false
    }
    settle(ref, on: context)
    return true
  }

  deinit {
    guard let context = contextReference.value,
      let ref = registryReference.bindings?.take(identity)
    else {
      return
    }
    settle(ref, on: context)
  }

  /// Enqueue the unprotect on the VM executor. A task-executor-backed VM
  /// enqueues immediately, so settlement keeps its position relative to the
  /// caller's later engine work.
  private func settle(_ ref: JSValueRef, on context: JSCContext) {
    let refBits = UInt(bitPattern: ref)
    scheduleOnTaskExecutor(context.virtualMachine.executor) {
      context.unprotectPersistentValue(refBits)
    }
  }

  public static func == (lhs: JSCPersistentHandle, rhs: JSCPersistentHandle) -> Bool {
    lhs.identity == rhs.identity
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identity)
  }
}
