@preconcurrency import JavaScriptCore.JSVirtualMachine
import Synchronization

public class JSVirtualMachine: @unchecked Sendable {
  let vm: JavaScriptCore.JSGlobalContextRef
  let unownedExecutor: UnownedSerialExecutor
  fileprivate let contexts: Mutex<[JSGlobalContextRef: JSContext]> = Mutex([:])

  public init() {
    self.vm = JSContextGroupCreate()
  }

  internal func context(for ref: JSGlobalContextRef) -> JSContext {
    contexts.withLock({ contexts in
      if let existing = contexts[ref] {
        return existing
      } else {
        let newContext = JSContext(virtualMachine: self)
        contexts[ref] = newContext
        return newContext
      }
    })
  }

  fileprivate func cache(context: JSContext) {
    contexts.withLock { contexts in
      contexts[context.context.jsGlobalContextRef] = context
    }
  }

  deinit {
    JSGlobalContextRelease(vm)
  }

}

@available(macOS 14.0, *)
private class SingleThreadExecutor: Executor, @unchecked Sendable {
  let runloop = RunLoop.init()

  func enqueue(_ job: consuming ExecutorJob) {

  }
}

public actor JSContext {
  let ref: JSGlobalContextRef
  public let virtualMachine: JSVirtualMachine
  nonisolated public let unownedExecutor: UnownedSerialExecutor

  public init(virtualMachine: JSVirtualMachine) {
    self.virtualMachine = virtualMachine
    let context = JSGlobalContextCreateInGroup(virtualMachine.vm, nil)!
    self.ref = context
    self.unownedExecutor = virtualMachine.unownedExecutor
    virtualMachine.cache(context: self)
  }

  public func withGlobalObject(_ body: (borrowing JSValue) -> Void) {
    let globalObject = JSValue(ref: JSContextGetGlobalObject(ref), ctx: ref)
    body(globalObject)
  }

  deinit {
    JSGlobalContextRelease(ref)
  }

}
