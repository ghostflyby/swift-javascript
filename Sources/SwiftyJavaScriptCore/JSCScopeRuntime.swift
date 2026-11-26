import JavaScriptCore
import SwiftJavaScript
import Synchronization

// MARK: - JavaScriptCore scope stack
//
// JSC is GC-managed: an owned reference is the raw `JSValueRef`, releasing is
// a no-op, and only explicit-rooting frames (the context default frame) take
// a `JSValueProtect` that must be balanced by `JSValueUnprotect` on drain or
// transfer. The stack is keyed by the raw context pointer.

final class JSCScopeFrame: @unchecked Sendable {
  let contextRef: JSGlobalContextRef
  private let rootsArenaValues: Bool
  private var values: [JSValueRef] = []

  init(contextRef: JSGlobalContextRef, rootsArenaValues: Bool) {
    self.contextRef = contextRef
    self.rootsArenaValues = rootsArenaValues
  }

  func track(_ ref: JSValueRef) {
    if rootsArenaValues {
      JSValueProtect(contextRef, ref)
    }
    values.append(ref)
  }

  func drain() {
    while let ref = values.popLast() {
      if rootsArenaValues {
        JSValueUnprotect(contextRef, ref)
      }
    }
  }

  func takeFirst(matching identity: (JSValueRef) -> Bool) -> JSValueRef? {
    guard let index = values.firstIndex(where: identity) else { return nil }
    let ref = values[index]
    values.remove(at: index)
    if rootsArenaValues {
      JSValueUnprotect(contextRef, ref)
    }
    return ref
  }

  func contains(matching identity: (JSValueRef) -> Bool) -> Bool {
    values.contains(where: identity)
  }
}

final class JSCScopeCore: @unchecked Sendable {
  let contextRef: JSGlobalContextRef
  let frame: JSCScopeFrame

  init(contextRef: JSGlobalContextRef, rootsArenaValues: Bool) {
    self.contextRef = contextRef
    self.frame = JSCScopeFrame(
      contextRef: contextRef,
      rootsArenaValues: rootsArenaValues
    )
  }

  func drain() {
    frame.drain()
  }

  func trackCreatedHandle(_ ref: JSValueRef) -> JSValueRef {
    frame.track(ref)
    return ref
  }

  func claimAndTrackHandle(_ ref: JSValueRef) -> JSValueRef {
    frame.track(ref)
    return ref
  }

  func transferToDefaultFrame(_ ref: JSValueRef) {
    let target = JSCScopeStacks.defaultFrame(for: contextRef) ?? frame
    if let taken = frame.takeFirst(matching: { $0 == ref }) {
      target.track(taken)
    } else {
      target.track(ref)
    }
  }

  func trackOnDefaultFrame(_ ref: JSValueRef) {
    let target = JSCScopeStacks.defaultFrame(for: contextRef) ?? frame
    target.track(ref)
  }
}

private final class JSCScopeStack: @unchecked Sendable {
  var frames: [JSCScopeFrame] = []
  var vmThread: VMThread?
}

private enum JSCScopeStackStorage {
  static let state = Mutex<[UInt: JSCScopeStack]>([:])
}

enum JSCScopeStacks {
  static func push(_ core: JSCScopeCore) {
    let key = UInt(bitPattern: core.contextRef)
    JSCScopeStackStorage.state.withLock { stacks in
      let stack = stacks[key] ?? JSCScopeStack()
      stack.frames.append(core.frame)
      stacks[key] = stack
    }
  }

  @discardableResult
  static func pop(for contextRef: JSGlobalContextRef) -> JSCScopeFrame? {
    let key = UInt(bitPattern: contextRef)
    return JSCScopeStackStorage.state.withLock { stacks in
      guard let stack = stacks[key] else { return nil }
      let popped = stack.frames.popLast()
      if stack.frames.isEmpty {
        stacks.removeValue(forKey: key)
      }
      return popped
    }
  }

  static func bind(_ vmThread: VMThread, for contextRef: JSGlobalContextRef) {
    let key = UInt(bitPattern: contextRef)
    JSCScopeStackStorage.state.withLock { stacks in
      stacks[key]?.vmThread = vmThread
    }
  }

  static func vmThread(for contextRef: JSGlobalContextRef) -> VMThread? {
    let key = UInt(bitPattern: contextRef)
    return JSCScopeStackStorage.state.withLock { stacks in
      stacks[key]?.vmThread
    }
  }

  static func top(of contextRef: JSGlobalContextRef) -> JSCScopeFrame? {
    let key = UInt(bitPattern: contextRef)
    return JSCScopeStackStorage.state.withLock { stacks in
      stacks[key]?.frames.last
    }
  }

  static func defaultFrame(for contextRef: JSGlobalContextRef) -> JSCScopeFrame? {
    let key = UInt(bitPattern: contextRef)
    return JSCScopeStackStorage.state.withLock { stacks in
      stacks[key]?.frames.first
    }
  }
}
