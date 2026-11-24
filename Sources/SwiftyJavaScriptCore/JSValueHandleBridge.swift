import JavaScriptCore

// MARK: - Surface value bridge (S4)
//
// These are the `JSCValue` counterparts of the former legacy value bridge;
// These are the `JSCValue` overloads. Both are non-owning
// identity wrappers: the caller (a scope arena or engine callback frame) still
// owns the reference.

extension JSCValue {
  init(ref: JSValueRef, ctx: isolated JSCContext) {
    self.init(
      handle: JSCValueHandle(ref: ref),
      contextHandle: ctx.driverContextHandle
    )
  }

  init(ref: JSValueRef, in context: borrowing JSCInstantContext) {
    self.init(
      handle: JSCValueHandle(ref: ref),
      contextHandle: context.driverContextHandle
    )
  }

  borrowing func borrowedRef() -> JSValueRef {
    borrowHandle().ref
  }

  var ref: JSValueRef {
    borrowHandle().ref
  }
}
