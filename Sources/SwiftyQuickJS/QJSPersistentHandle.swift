import SwiftJavaScript

/// A persistent, Sendable identity for a QuickJS value bound in a
/// context-side binding table.
///
/// QuickJS counterpart of `JSCPersistentHandle`: public identity plus a weak
/// view of the table and of the context actor. Settlement is reference-counted
/// (`JS_FreeValue`), so the payload is freed on the VM executor exactly once.
public final class QJSPersistentHandle: SwiftJavaScript.JSPersistentHandle, Sendable {
  public let identity: JSPersistentHandleIdentity

  private let bindingsReference: QJSPersistentBindingsReference
  /// Weak: a surviving handle must not keep the context alive. A dead context
  /// already released its bindings at teardown.
  private let contextReference: QJSContextReference

  init(
    identity: JSPersistentHandleIdentity,
    registry: QJSPersistentBindings,
    context: QJSContext
  ) {
    self.identity = identity
    self.bindingsReference = QJSPersistentBindingsReference(registry)
    self.contextReference = QJSContextReference(context)
  }

  @discardableResult
  public func invalidate() -> Bool {
    guard let context = contextReference.value,
      let value = bindingsReference.bindings?.take(identity)
    else {
      return false
    }
    settle(value, on: context)
    return true
  }

  deinit {
    guard let context = contextReference.value,
      let value = bindingsReference.bindings?.take(identity)
    else {
      return
    }
    settle(value, on: context)
  }

  /// Enqueue the free on the VM executor. The executor is a task executor, so
  /// it enqueues immediately and settlement keeps its position relative to the
  /// caller's later engine work.
  private func settle(_ value: CQuickJSValue, on context: QJSContext) {
    scheduleOnSerialExecutor(context.virtualMachine.executor) {
      context.freePersistentValue(value)
    }
  }

  public static func == (lhs: QJSPersistentHandle, rhs: QJSPersistentHandle) -> Bool {
    lhs.identity == rhs.identity
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identity)
  }
}
