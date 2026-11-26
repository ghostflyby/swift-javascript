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

package struct QJSRuntimeHandle: JSRuntimeManualReferenceCountedHandle, @unchecked Sendable {
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
  package func retainReference() -> Bool {
    false
  }

  @discardableResult
  package func releaseReference() -> Bool {
    guard ownsRuntime else {
      return false
    }
    JS_FreeRuntime(ref)
    removeQuickJSClassRecords(in: self)
    quickJSRuntimeIdentityRegistry.removeID(for: rawRef)
    return true
  }
}

extension QJSRuntimeHandle: Hashable {
  package static func == (lhs: QJSRuntimeHandle, rhs: QJSRuntimeHandle) -> Bool {
    lhs.rawRef == rhs.rawRef && lhs.runtimeID == rhs.runtimeID
  }

  package func hash(into hasher: inout Hasher) {
    hasher.combine(rawRef)
    hasher.combine(runtimeID)
  }
}

package struct QJSContextHandle: JSContextManualReferenceCountedHandle, @unchecked Sendable {
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
  package func retainReference() -> Bool {
    let duplicated = JS_DupContext(ref)
    return duplicated != nil
  }

  @discardableResult
  package func releaseReference() -> Bool {
    JS_FreeContext(ref)
    return true
  }
}

extension QJSContextHandle: Hashable {
  package static func == (lhs: QJSContextHandle, rhs: QJSContextHandle) -> Bool {
    lhs.rawRef == rhs.rawRef
  }

  package func hash(into hasher: inout Hasher) {
    hasher.combine(rawRef)
  }
}

package struct QJSValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable, Hashable {
  package typealias Context = QJSContextHandle
  package typealias Owned = QJSOwnedValueHandle

  let rawRef: CQuickJSValue

  init(ref: CQuickJSValue) {
    self.rawRef = ref
  }

  var ref: CQuickJSValue {
    return rawRef
  }

  /// Full-identity equality: tag plus the complete 8-byte union payload.
  /// Comparing only `u.int32` truncates heap pointers to their low 32 bits,
  /// which lets two distinct live objects collide and corrupts identity
  /// matching (e.g. the scope arena's persist removal).
  package static func == (lhs: Self, rhs: Self) -> Bool {
    guard lhs.rawRef.tag == rhs.rawRef.tag else { return false }
    return withUnsafeBytes(of: lhs.rawRef.u) { lhsBytes in
      withUnsafeBytes(of: rhs.rawRef.u) { rhsBytes in
        lhsBytes.elementsEqual(rhsBytes)
      }
    }
  }

  package func hash(into hasher: inout Hasher) {
    hasher.combine(rawRef.tag)
    withUnsafeBytes(of: rawRef.u) { hasher.combine($0.load(as: UInt64.self)) }
  }

  package func retainReference(in context: QJSContextHandle) {
    _ = JS_DupValue(context.ref, rawRef)
  }

  package func releaseReference(in context: QJSContextHandle) {
    JS_FreeValue(context.ref, rawRef)
  }

}

/// Ownership carrier for a QuickJS value reference (`~Copyable`).
///
/// QuickJS is reference-counted: every engine creation or value-operation
/// call returns a +1 reference. Wrapping exactly those results in this
/// noncopyable type makes double frees (and lost releases) a compile-time
/// error — the owned reference can live in only one place (creation
/// result, scope-arena element, or handoff).
package struct QJSOwnedValueHandle: JSOwnedValueManualReferenceCountedHandle,
  Equatable, ~Copyable
{
  package typealias Context = QJSContextHandle
  package typealias Borrowed = QJSValueHandle

  let rawRef: CQuickJSValue

  init(ref: CQuickJSValue) {
    self.rawRef = ref
  }

  package borrowing func borrowed() -> QJSValueHandle {
    QJSValueHandle(ref: rawRef)
  }

  package static func adopting(_ handle: borrowing QJSValueHandle) -> Self {
    Self(ref: handle.rawRef)
  }

  package static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool {
    guard lhs.rawRef.tag == rhs.rawRef.tag else { return false }
    return withUnsafeBytes(of: lhs.rawRef.u) { lhsBytes in
      withUnsafeBytes(of: rhs.rawRef.u) { rhsBytes in
        lhsBytes.elementsEqual(rhsBytes)
      }
    }
  }
}

package struct QJSClassHandle: JSClassManualReferenceCountedHandle, @unchecked Sendable {
  let id: JSClassID
  let runtime: QJSRuntimeHandle?

  package init(id: JSClassID, runtime: QJSRuntimeHandle? = nil) {
    self.id = id
    self.runtime = runtime
  }

  @discardableResult
  package func retainReference() -> Bool {
    false
  }

  @discardableResult
  package func releaseReference() -> Bool {
    false
  }
}

extension QJSClassHandle: Hashable {}

package struct QJSPropertyStringKeyHandle: JSPropertyStringKeyManualReferenceCountedHandle,
  @unchecked Sendable
{
  let atom: JSAtom
  let contextRef: OpaquePointer

  init(atom: JSAtom, contextRef: OpaquePointer) {
    self.atom = atom
    self.contextRef = contextRef
  }

  @discardableResult
  package func retainReference() -> Bool {
    JS_DupAtom(contextRef, atom) != 0
  }

  @discardableResult
  package func releaseReference() -> Bool {
    JS_FreeAtom(contextRef, atom)
    return true
  }
}

package struct QJSPreparedScriptHandle: JSPreparedScriptManualReferenceCountedHandle,
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
  package func retainReference() -> Bool {
    true
  }

  @discardableResult
  package func releaseReference() -> Bool {
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
