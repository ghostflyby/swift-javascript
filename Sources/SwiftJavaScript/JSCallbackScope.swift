import Foundation

/// Per-thread LIFO stack of callback context handles.
internal final class ScopeStack: @unchecked Sendable {
  private var frames: [any JSContextManualReferenceCountedHandle] = []

  func push(_ context: any JSContextManualReferenceCountedHandle) { frames.append(context) }
  @discardableResult
  func pop() -> (any JSContextManualReferenceCountedHandle)? { frames.popLast() }
  var top: (any JSContextManualReferenceCountedHandle)? { frames.last }
  var isEmpty: Bool { frames.isEmpty }
}

// MARK: - Runtime scope registry

/// Per-thread registry of per-context scope stacks and the active context.
/// Stored as a single object in Thread.threadDictionary so mutations happen
/// in place without copying dictionaries in and out of TLS.
private final class RuntimeScopeRegistry: NSObject, @unchecked Sendable {
  var stacks: [AnyHashable: ScopeStack] = [:]
  var activeContext: AnyHashable?
}

/// Stable identity-based sentinel key in Thread.threadDictionary.
private final class RegistrySentinel: NSObject, @unchecked Sendable {}
private let registrySentinel = RegistrySentinel()

// MARK: - TLS-backed per-context scope stacks

internal enum TLSCallbackStack {

  private static func tlsDictionary() -> NSMutableDictionary {
    Thread.current.threadDictionary
  }

  private static func registry() -> RuntimeScopeRegistry {
    if let existing = tlsDictionary()[registrySentinel] as? RuntimeScopeRegistry {
      return existing
    }
    let new = RuntimeScopeRegistry()
    tlsDictionary()[registrySentinel] = new
    return new
  }

  // MARK: - Active runtime

  static func push(_ context: any JSContextManualReferenceCountedHandle, key: AnyHashable) {
    let reg = registry()
    reg.activeContext = key
    let s = reg.stacks[key] ?? ScopeStack()
    s.push(context)
    reg.stacks[key] = s
  }

  @discardableResult
  static func pop(key: AnyHashable) -> (any JSContextManualReferenceCountedHandle)? {
    let reg = registry()
    guard let s = reg.stacks[key] else { return nil }
    let popped = s.pop()
    if s.isEmpty {
      reg.stacks.removeValue(forKey: key)
      reg.activeContext = nil
    }
    return popped
  }

  /// Returns the top context handle for the currently active context, or nil.
  static var top: (any JSContextManualReferenceCountedHandle)? {
    let reg = registry()
    guard let active = reg.activeContext,
      let s = reg.stacks[active]
    else { return nil }
    return s.top
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

  private let contextKey: AnyHashable

  /// Push a new frame onto the thread-local scope stack.
  package init(contextHandle: E.ContextHandle) {
    self.context = JSInstantContext<E>(handle: contextHandle)
    self.contextKey = AnyHashable(contextHandle)
    TLSCallbackStack.push(
      contextHandle,
      key: contextKey
    )
  }

  /// Pop the scope's frame from the TLS stack.
  deinit {
    TLSCallbackStack.pop(key: contextKey)
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
