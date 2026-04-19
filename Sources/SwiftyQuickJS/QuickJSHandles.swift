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
  let ref: OpaquePointer
  let ownsRuntime: Bool

  init(ref: OpaquePointer, ownsRuntime: Bool = true) {
    self.ref = ref
    self.ownsRuntime = ownsRuntime
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
    lhs.ref == rhs.ref
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ref)
  }
}

public struct QuickJSContextHandle: JSContextManualReferenceCountedHandle, @unchecked Sendable {
  let ref: OpaquePointer

  init(ref: OpaquePointer) {
    self.ref = ref
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
    lhs.ref == rhs.ref
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ref)
  }
}

public struct QuickJSValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {

  let ref: CQuickJSValue
  let contextRef: OpaquePointer

  init(ref: CQuickJSValue, contextRef: OpaquePointer, ownsValue: Bool = true) {
    self.ref = ref
    self.contextRef = contextRef
  }

  @discardableResult
  public func retainReference() -> Bool {
    _ = JS_DupValue(contextRef, ref)
    return true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    JS_FreeValue(contextRef, ref)
    return true
  }

  public var storageWords: JSValueStorageWords {
    (
      word0: UInt64(bitPattern: ref.tag),
      word1: unsafeBitCast(ref.u, to: UInt64.self),
      word2: UInt64(UInt(bitPattern: contextRef))
    )
  }

  public init(storageWords: JSValueStorageWords) {
    let tag = Int64(bitPattern: storageWords.word0)
    let valueUnion = unsafeBitCast(storageWords.word1, to: JSValueUnion.self)
    self.ref = CQuickJSValue(u: valueUnion, tag: tag)
    self.contextRef = OpaquePointer(bitPattern: UInt(storageWords.word2))!
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
