import CQuickJS
import Foundation
import SwiftJavaScript

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

public final class QuickJSValueHandle: JSValueManualReferenceCountedHandle, @unchecked Sendable {
  let ref: CQuickJS.JSValue
  let contextRef: OpaquePointer
  private let ownsValue: Bool
  private var released = false

  init(ref: CQuickJS.JSValue, contextRef: OpaquePointer, ownsValue: Bool = true) {
    self.ref = ref
    self.contextRef = contextRef
    self.ownsValue = ownsValue
  }

  deinit {
    _ = releaseReference()
  }

  @discardableResult
  public func retainReference() -> Bool {
    true
  }

  @discardableResult
  public func releaseReference() -> Bool {
    guard ownsValue, !released else {
      return false
    }
    released = true
    JS_FreeValue(contextRef, ref)
    return true
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

final class QuickJSFunctionCallbackBox: @unchecked Sendable {
  let callback: JSFunctionCallback<QuickJSEngine>

  init(callback: @escaping JSFunctionCallback<QuickJSEngine>) {
    self.callback = callback
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
