import Synchronization
import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

// MARK: - QuickJS scope stack
//
// QuickJS is reference-counted: an owned reference is a `CQuickJSValue` that
// must be handed to `JS_FreeValue` exactly once, and claiming a borrowed one
// is a `JS_DupValue`. A frame owns the creation references created inside its
// window and settles them on drain; `persist` moves one reference to the
// context default frame without touching its count. The stack is keyed by the
// raw context pointer.

/// Refresh the runtime's recorded stack top before an engine call.
@inline(__always)
func quickJSUpdateStackTop(_ contextRef: OpaquePointer) {
  JS_UpdateStackTop(JS_GetRuntime(contextRef))
}

/// Full-identity comparison of two QuickJS values: tag plus the complete
/// 8-byte union payload. Comparing only `u.int32` truncates heap pointers to
/// their low 32 bits, which lets two distinct live objects collide and
/// corrupts the arena's `persist` removal.
func quickJSValueIdentityEquals(_ lhs: CQuickJSValue, _ rhs: CQuickJSValue) -> Bool {
  guard lhs.tag == rhs.tag else { return false }
  return withUnsafeBytes(of: lhs.u) { lhsBytes in
    withUnsafeBytes(of: rhs.u) { rhsBytes in
      lhsBytes.elementsEqual(rhsBytes)
    }
  }
}

/// A scope's release ledger: every element is one owned reference (`+1`) that
/// its creation call produced. `drain` hands each element still present to
/// `JS_FreeValue` exactly once.
final class QJSScopeFrame: @unchecked Sendable {
  let contextRef: OpaquePointer
  private var values: [CQuickJSValue] = []

  init(contextRef: OpaquePointer) {
    self.contextRef = contextRef
  }

  /// Take ownership of one creation reference and settle it on drain.
  func track(_ value: CQuickJSValue) {
    values.append(value)
  }

  func drain() {
    guard !values.isEmpty else { return }
    quickJSUpdateStackTop(contextRef)
    while let value = values.popLast() {
      JS_FreeValue(contextRef, value)
    }
  }

  /// Remove the first element matching `identity` and hand its owned reference
  /// to the caller without settling it: the reference is transferred, not
  /// copied.
  func takeFirst(matching identity: (CQuickJSValue) -> Bool) -> CQuickJSValue? {
    guard let index = values.firstIndex(where: identity) else { return nil }
    return values.remove(at: index)
  }

  func contains(matching identity: (CQuickJSValue) -> Bool) -> Bool {
    values.contains(where: identity)
  }
}

/// The scope's ledger plus the one claim operation the reference-counted
/// engine needs: a borrowed value is duplicated before the arena adopts it.
final class QJSScopeCore: @unchecked Sendable {
  let contextRef: OpaquePointer
  let frame: QJSScopeFrame

  init(contextRef: OpaquePointer) {
    self.contextRef = contextRef
    self.frame = QJSScopeFrame(contextRef: contextRef)
  }

  func drain() {
    frame.drain()
  }

  /// Adopt an engine-created reference: track it exactly once and hand back
  /// the same value for the local view.
  func trackCreated(_ value: CQuickJSValue) -> CQuickJSValue {
    frame.track(value)
    return value
  }

  /// Claim a borrowed value for an arena that does not own it yet
  /// (`JS_DupValue`) and track the claimed reference. The borrowed identity is
  /// returned unchanged for the local view.
  func claimAndTrack(_ value: CQuickJSValue) -> CQuickJSValue {
    quickJSUpdateStackTop(contextRef)
    frame.track(JS_DupValue(contextRef, value))
    return value
  }

  /// Move the reference behind `value` out of this scope's frame into the
  /// context default frame. A frame-owned reference is transferred (no
  /// duplicate); any other one is claimed once. A bare context has no default
  /// frame, so the reference then stays on this scope's own frame.
  func transferToDefaultFrame(_ value: CQuickJSValue) {
    let target = QJSScopeStacks.defaultFrame(for: contextRef) ?? frame
    if let taken = frame.takeFirst(matching: { quickJSValueIdentityEquals($0, value) }) {
      target.track(taken)
    } else {
      quickJSUpdateStackTop(contextRef)
      target.track(JS_DupValue(contextRef, value))
    }
  }

  /// Track a created reference on the context default frame: for values meant
  /// to outlive this window, such as function values stored as properties.
  func trackOnDefaultFrame(_ value: CQuickJSValue) {
    let target = QJSScopeStacks.defaultFrame(for: contextRef) ?? frame
    target.track(value)
  }
}

private final class QJSScopeStack: @unchecked Sendable {
  var frames: [QJSScopeFrame] = []
  var vmThread: VMThread?
}

private enum QJSScopeStackStorage {
  static let state = Mutex<[UInt: QJSScopeStack]>([:])
}

enum QJSScopeStacks {
  static func push(_ core: QJSScopeCore) {
    let key = UInt(bitPattern: core.contextRef)
    QJSScopeStackStorage.state.withLock { stacks in
      let stack = stacks[key] ?? QJSScopeStack()
      stack.frames.append(core.frame)
      stacks[key] = stack
    }
  }

  @discardableResult
  static func pop(for contextRef: OpaquePointer) -> QJSScopeFrame? {
    let key = UInt(bitPattern: contextRef)
    return QJSScopeStackStorage.state.withLock { stacks in
      guard let stack = stacks[key] else { return nil }
      let popped = stack.frames.popLast()
      if stack.frames.isEmpty {
        stacks.removeValue(forKey: key)
      }
      return popped
    }
  }

  static func bind(_ vmThread: VMThread, for contextRef: OpaquePointer) {
    let key = UInt(bitPattern: contextRef)
    QJSScopeStackStorage.state.withLock { stacks in
      stacks[key]?.vmThread = vmThread
    }
  }

  static func vmThread(for contextRef: OpaquePointer) -> VMThread? {
    let key = UInt(bitPattern: contextRef)
    return QJSScopeStackStorage.state.withLock { stacks in
      stacks[key]?.vmThread
    }
  }

  static func top(of contextRef: OpaquePointer) -> QJSScopeFrame? {
    let key = UInt(bitPattern: contextRef)
    return QJSScopeStackStorage.state.withLock { stacks in
      stacks[key]?.frames.last
    }
  }

  /// The stack bottom: the context default frame values promoted by `persist`
  /// belong to.
  static func defaultFrame(for contextRef: OpaquePointer) -> QJSScopeFrame? {
    let key = UInt(bitPattern: contextRef)
    return QJSScopeStackStorage.state.withLock { stacks in
      stacks[key]?.frames.first
    }
  }
}
