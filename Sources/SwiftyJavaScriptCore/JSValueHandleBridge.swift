import Foundation

struct _JSValueRawStorage: ~Copyable {
  let ref: JavaScriptCoreValueRef
}

private final class _JSValueContextRegistry: @unchecked Sendable {
  static let shared = _JSValueContextRegistry()

  private let lock = NSLock()
  private var contextRefs: [UInt: JavaScriptCoreContextRef] = [:]

  func register(ref: JavaScriptCoreValueRef, contextRef: JavaScriptCoreContextRef) {
    lock.lock()
    contextRefs[UInt(bitPattern: ref)] = contextRef
    lock.unlock()
  }

  func contextRef(for ref: JavaScriptCoreValueRef) -> JavaScriptCoreContextRef? {
    lock.lock()
    let contextRef = contextRefs[UInt(bitPattern: ref)]
    lock.unlock()
    return contextRef
  }
}

extension JSValue {
  var ref: JavaScriptCoreValueRef {
    _rawValue.ref
  }

  var ctx: JavaScriptCoreContextRef {
    guard let contextRef = _JSValueContextRegistry.shared.contextRef(for: ref) else {
      preconditionFailure(
        "Missing context for JSValue; construct or bridge it with an explicit context")
    }
    return contextRef
  }

  /// Wrap a JavaScriptCore value reference into backend raw value storage.
  /// - Parameters:
  ///   - ref: The JavaScriptCoreValueRef to wrap
  ///   - ctx: The JSContext in which the value exists
  init(ref: JavaScriptCoreValueRef, ctx: isolated JSContext = #isolation) {
    self._rawValue = _JSValueRawStorage(ref: ref)
    _JSValueContextRegistry.shared.register(ref: ref, contextRef: ctx.globalContextRef)
  }

  init(ref: JavaScriptCoreValueRef, ctx: borrowing JSInstantContext) {
    self._rawValue = _JSValueRawStorage(ref: ref)
    _JSValueContextRegistry.shared.register(ref: ref, contextRef: ctx.globalContextRef)
  }

  consuming func retainedRef() -> JavaScriptCoreValueRef {
    ref
  }

  init(handleValue: JSValueHandle<JavaScriptCoreEngine>) {
    guard let rawValue: JavaScriptCoreRawValue = handleValue.opaqueHandle() else {
      preconditionFailure("JSValue handle did not contain JavaScriptCoreRawValue")
    }
    self.init(rawValue: rawValue)
  }

  init(rawValue: JavaScriptCoreRawValue) {
    self._rawValue = _JSValueRawStorage(ref: rawValue.ref)
    _JSValueContextRegistry.shared.register(ref: rawValue.ref, contextRef: rawValue.context.ref)
  }

  func rawValue(in context: JavaScriptCoreRawContext) -> JavaScriptCoreRawValue {
    return JavaScriptCoreRawValue(ref: ref, context: context)
  }

  func valueHandle(in context: borrowing JSInstantContext) -> JSValueHandle<JavaScriptCoreEngine> {
    JSValueHandle<JavaScriptCoreEngine>(_opaqueHandle: rawValue(in: context.driverContext))
  }
}
