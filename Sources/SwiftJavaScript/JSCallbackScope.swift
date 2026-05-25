/// A single frame on the per-thread callback scope stack.
import Foundation

/// Returns whether the current thread is inside an active callback scope for the given engine type.
internal func isInsideCallbackScope<E: JSEngine>(for _: E.Type) -> Bool {
  guard let frame = TLSCallbackStack.top,
    frame.engineTypeID == ObjectIdentifier(E.self)
  else { return false }
  return true
}

internal struct JSCallbackScopeFrame: @unchecked Sendable {
  let contextBox: any JSContextManualReferenceCountedHandle
  let engineTypeID: ObjectIdentifier  // ObjectIdentifier(E.self)
}

/// Per-thread LIFO stack of callback scope frames.
internal final class ScopeStack: @unchecked Sendable {
  private var frames: [JSCallbackScopeFrame] = []

  func push(_ frame: JSCallbackScopeFrame) { frames.append(frame) }
  func pop() { frames.removeLast() }
  var top: JSCallbackScopeFrame? { frames.last }
}

/// Thread-local access to the callback scope stack.
private let tlsKey = "com.swiftjavascript.scopeStack"

internal enum TLSCallbackStack {
  static func push(_ frame: JSCallbackScopeFrame) {
    stack().push(frame)
  }

  static func pop() {
    stack().pop()
  }

  static var top: JSCallbackScopeFrame? {
    stack().top
  }

  private static func stack() -> ScopeStack {
    let dict = Thread.current.threadDictionary
    if let existing = dict[tlsKey] as? ScopeStack { return existing }
    let new = ScopeStack()
    dict[tlsKey] = new
    return new
  }
}

// MARK: - JSCallbackReturn

/// The return value of a JS callback, representing either a borrowed temporary
/// value handle or an owned persistent JSValue.
public struct JSCallbackReturn<E: JSEngine>: ~Copyable {
  package let handle: JSValueHandle<E>
  package let isPersistent: Bool
  package let isException: Bool

  package init(temporary handle: JSValueHandle<E>) {
    self.handle = handle
    self.isPersistent = false
    self.isException = false
  }

  package init(persistent value: consuming JSValue<E>) {
    self.handle = value.takeHandle()
    self.isPersistent = true
    self.isException = false
  }

  package init(exception handle: JSValueHandle<E>) {
    self.handle = handle
    self.isPersistent = false
    self.isException = true
  }
}

// MARK: - JSCallbackScope

/// A callback scope that pushes a context frame onto the per-thread TLS stack.
///
/// Create one at the top of every C → Swift callback entry point.
/// The scope is `~Copyable` so its deinit deterministically pops the TLS frame.
///
/// Provided API:
/// - `persist(_:)` — Upgrade a `JSCallbackValue` to an owning `JSValue`
/// - `return(_:)` — Wrap a value for callback return
/// - Value factories (`makeString`, `makeNumber`, etc.) — Delegated to `JSInstantContext`
public struct JSCallbackScope<E: JSEngine>: ~Copyable {
  /// The instant context for creating persistent values inside callbacks.
  public let context: JSInstantContext<E>

  /// Unique identifier for this scope instance.

  /// Push a new frame onto the thread-local scope stack.
  package init(contextHandle: E.ContextHandle) {
    self.context = JSInstantContext<E>(handle: contextHandle)
    TLSCallbackStack.push(
      JSCallbackScopeFrame(
        contextBox: contextHandle,
        engineTypeID: ObjectIdentifier(E.self)
      ))
  }

  /// Pop the scope's frame from the TLS stack.
  deinit {
    TLSCallbackStack.pop()
  }

  // MARK: - Persist

  /// Upgrade a temporary callback value to a persistent `JSValue`.
  ///
  /// The value's underlying handle is retained (e.g., `JSValueProtect` for JSC,
  /// `JS_DupValue` for QuickJS) and wrapped in an owning `JSValue`.
  public func persist(_ value: borrowing JSCallbackValue<E>) -> JSValue<E> {
    value.handle.retainReference(in: context.driverContextHandle)
    return JSValue(handleValue: value.handle, in: context.driverContextHandle)
  }

  // MARK: - Return value construction

  /// Wrap a temporary value as a callback return value (borrowed handle).
  public func `return`(_ value: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> {
    return JSCallbackReturn(temporary: value.handle)
  }

  /// Wrap a persistent JSValue as a callback return value (owned).
  public func `return`(_ value: consuming JSValue<E>) -> JSCallbackReturn<E> {
    JSCallbackReturn(persistent: value)
  }

  /// Mark a JS exception return value (borrowed temporary handle).
  public func `throw`(_ value: borrowing JSCallbackValue<E>) -> JSCallbackReturn<E> {
    return JSCallbackReturn(exception: value.handle)
  }

  /// Mark a JS exception return value (owned persistent JSValue).

  /// Return an undefined value (convenience).
  public func returnUndefined() -> JSCallbackReturn<E> {
    let h: JSValueHandle<E> = context.makeUndefined().handle
    return JSCallbackReturn(temporary: h)
  }

  /// Throw an undefined exception (convenience).
  public func throwUndefined() -> JSCallbackReturn<E> {
    let h: JSValueHandle<E> = context.makeUndefined().handle
    return JSCallbackReturn(exception: h)
  }

  // MARK: - Value factories (delegated to JSInstantContext)

  public func makeString(_ value: String) -> JSValue<E> { context.makeString(value) }
  public func makeString(from key: borrowing JSPropertyStringKey<E>) -> JSValue<E> {
    context.makeString(from: key)
  }
  public func makeNumber(_ value: Double) -> JSValue<E> { context.makeNumber(value) }
  public func makeNumber(_ value: some BinaryInteger) -> JSValue<E> { context.makeNumber(value) }
  public func makeBoolean(_ value: Bool) -> JSValue<E> { context.makeBoolean(value) }
  public func makeNull() -> JSValue<E> { context.makeNull() }
  public func makeUndefined() -> JSValue<E> { context.makeUndefined() }
  public func makeObject() -> JSValue<E> { context.makeObject() }
  public func makeArray() -> JSValue<E> { context.makeArray() }
}
