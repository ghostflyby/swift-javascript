import Foundation
import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

public struct QuickJSRuntimeHandle: JSRuntimeManualReferenceCountedHandle, @unchecked Sendable {
  private let rawRef: OpaquePointer
  let ownsRuntime: Bool

  init(ref: OpaquePointer, ownsRuntime: Bool = true) {
    self.rawRef = ref
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
    return true
  }
}

extension QuickJSRuntimeHandle: Hashable {
  public static func == (lhs: QuickJSRuntimeHandle, rhs: QuickJSRuntimeHandle) -> Bool {
    lhs.rawRef == rhs.rawRef
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(rawRef)
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

  public func bindContextOwner<E>(_ owner: SwiftJavaScript.JSContext<E>)
  where QuickJSContextHandle == E.ContextHandle, E: SwiftJavaScript.JSEngine {

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

  public init(id: JSClassID) {
    self.id = id
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

public final class QuickJSStringHandle: JSStringManualReferenceCountedHandle, @unchecked Sendable {
  private let count: Int
  private let storage: UnsafeMutablePointer<UInt16>

  public init(_ value: String) {
    let units = Array(value.utf16)
    count = units.count
    storage = .allocate(capacity: max(1, count))
    if count > 0 {
      storage.initialize(from: units, count: count)
    }
  }

  deinit {
    if count > 0 {
      storage.deinitialize(count: count)
    }
    storage.deallocate()
  }

  var length: Int { count }
  var characters: UnsafePointer<UInt16> { UnsafePointer(storage) }

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
