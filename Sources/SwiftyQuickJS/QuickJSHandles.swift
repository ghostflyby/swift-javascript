import Foundation
import SwiftJavaScript
import Synchronization

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

private struct QuickJSRuntimeIdentityRegistry: Sendable, ~Copyable {
  struct State {
    var nextID: UInt64 = 1
    var runtimeIDs: [UInt: UInt64] = [:]
  }

  private let state = Mutex(State())

  func id(for runtime: OpaquePointer, ownsRuntime: Bool) -> UInt64 {
    let key = UInt(bitPattern: runtime)
    return state.withLock { state in
      if let id = state.runtimeIDs[key] {
        return id
      }
      guard ownsRuntime else {
        return UInt64(key)
      }
      let id = state.nextID
      state.nextID += 1
      state.runtimeIDs[key] = id
      return id
    }
  }

  func removeID(for runtime: OpaquePointer) {
    let key = UInt(bitPattern: runtime)
    _ = state.withLock {
      $0.runtimeIDs.removeValue(forKey: key)
    }
  }
}

private let quickJSRuntimeIdentityRegistry = QuickJSRuntimeIdentityRegistry()

public struct QuickJSRuntimeHandle: JSRuntimeManualReferenceCountedHandle, @unchecked Sendable {
  private let rawRef: OpaquePointer
  private let runtimeID: UInt64
  let ownsRuntime: Bool

  init(ref: OpaquePointer, ownsRuntime: Bool = true) {
    self.rawRef = ref
    self.runtimeID = quickJSRuntimeIdentityRegistry.id(for: ref, ownsRuntime: ownsRuntime)
    self.ownsRuntime = ownsRuntime
  }

  var ref: OpaquePointer {
    updateStackTop()
    return rawRef
  }

  @inline(__always)
  func updateStackTop() {
    JS_UpdateStackTop(rawRef)
  }

  @discardableResult
  public func retainReference() -> Bool {
    false
  }

  @discardableResult
  public func releaseReference() -> Bool {
    guard ownsRuntime else {
      return false
    }
    JS_FreeRuntime(ref)
    removeJSClassValueConvertibleClasses(for: QuickJSEngine.self, in: self)
    removeQuickJSClassRecords(in: self)
    quickJSRuntimeIdentityRegistry.removeID(for: rawRef)
    return true
  }
}

extension QuickJSRuntimeHandle: Hashable {
  public static func == (lhs: QuickJSRuntimeHandle, rhs: QuickJSRuntimeHandle) -> Bool {
    lhs.rawRef == rhs.rawRef && lhs.runtimeID == rhs.runtimeID
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawRef)
    hasher.combine(runtimeID)
  }
}

public struct QuickJSContextHandle: JSContextManualReferenceCountedHandle, @unchecked Sendable {
  private let rawRef: OpaquePointer

  init(ref: OpaquePointer) {
    self.rawRef = ref
  }

  var ref: OpaquePointer {
    updateStackTop()
    return rawRef
  }

  @inline(__always)
  func updateStackTop() {
    JS_UpdateStackTop(JS_GetRuntime(rawRef))
  }

  @discardableResult
  public func retainReference() -> Bool {
    let duplicated = JS_DupContext(ref)
    return duplicated != nil
  }

  @discardableResult
  public func releaseReference() -> Bool {
    JS_FreeContext(ref)
    return true
  }
}


extension QuickJSContextHandle: Hashable {
  public static func == (lhs: QuickJSContextHandle, rhs: QuickJSContextHandle) -> Bool {
    lhs.rawRef == rhs.rawRef
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawRef)
  }
}

public struct QuickJSValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {

  private let rawRef: CQuickJSValue
  private let rawContextRef: OpaquePointer

  init(ref: CQuickJSValue, contextRef: OpaquePointer, ownsValue: Bool = true) {
    self.rawRef = ref
    self.rawContextRef = contextRef
  }

  var ref: CQuickJSValue {
    updateStackTop()
    return rawRef
  }

  var contextRef: OpaquePointer {
    updateStackTop()
    return rawContextRef
  }

  @inline(__always)
  func updateStackTop() {
    JS_UpdateStackTop(JS_GetRuntime(rawContextRef))
  }

  @discardableResult
  public func retainReference() -> Bool {
    updateStackTop()
    _ = JS_DupValue(rawContextRef, rawRef)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    updateStackTop()
    JS_FreeValue(rawContextRef, rawRef)
    return true
  }

  public var storageWords: JSValueStorageWords {
    updateStackTop()
    return (
      word0: UInt64(bitPattern: rawRef.tag),
      word1: unsafeBitCast(rawRef.u, to: UInt64.self),
      word2: UInt64(UInt(bitPattern: rawContextRef))
    )
  }

  public init(storageWords: JSValueStorageWords) {
    let tag = Int64(bitPattern: storageWords.word0)
    let valueUnion = unsafeBitCast(storageWords.word1, to: JSValueUnion.self)
    self.rawRef = CQuickJSValue(u: valueUnion, tag: tag)
    self.rawContextRef = OpaquePointer(bitPattern: UInt(storageWords.word2))!
  }
}

public struct QuickJSClassHandle: JSClassManualReferenceCountedHandle, @unchecked Sendable {
  let id: JSClassID
  let runtime: QuickJSRuntimeHandle?

  public init(id: JSClassID, runtime: QuickJSRuntimeHandle? = nil) {
    self.id = id
    self.runtime = runtime
  }

  @discardableResult
  public func retainReference() -> Bool {
    false
  }

  @discardableResult
  public func releaseReference() -> Bool {
    false
  }
}

extension QuickJSClassHandle: Hashable {}

public struct QuickJSPropertyStringKeyHandle: JSPropertyStringKeyManualReferenceCountedHandle,
  @unchecked Sendable
{
  let atom: JSAtom
  let contextRef: OpaquePointer

  init(atom: JSAtom, contextRef: OpaquePointer) {
    self.atom = atom
    self.contextRef = contextRef
  }

  @discardableResult
  public func retainReference() -> Bool {
    JS_DupAtom(contextRef, atom) != 0
  }

  @discardableResult
  public func releaseReference() -> Bool {
    JS_FreeAtom(contextRef, atom)
    return true
  }
}

public struct QuickJSPreparedScriptHandle: JSPreparedScriptManualReferenceCountedHandle,
  @unchecked Sendable
{
  let source: String
  let contextRef: OpaquePointer

  init(source: String, contextRef: OpaquePointer) {
    self.source = source
    self.contextRef = contextRef
  }

  var byteCount: Int {
    source.utf8.count
  }

  func withCString<R>(_ body: (UnsafePointer<CChar>, Int) -> R) -> R {
    source.withCString { pointer in
      body(pointer, byteCount)
    }
  }

  @discardableResult
  public func retainReference() -> Bool {
    true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    true
  }
}

final class QuickJSArrayBufferDeallocatorBox: @unchecked Sendable {
  let deallocator: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void
  let context: UnsafeMutableRawPointer?

  init(
    deallocator:
      @escaping @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void,
    context: UnsafeMutableRawPointer?
  ) {
    self.deallocator = deallocator
    self.context = context
  }
}
