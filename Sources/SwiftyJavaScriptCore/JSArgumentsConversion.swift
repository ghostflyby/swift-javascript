extension JSArguments {
  public func tryUnpack<each T: JSValueDecodable>(
    types: repeat (each T).Type, in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> (repeat each T) {
    var idx = 0
    let pointer = self.pointer
    let nextJSValue: () -> JSValue = {
      defer { idx += 1 }
      if let v = pointer[idx] {
        return JSValue(ref: v, ctx: context)
      } else {
        return JSValue(undefinedIn: context)
      }
    }
    return
      (repeat try (each T).tryDecode(nextJSValue(), in: context))

  }

  public func tryUnpack<each T: JSRuntimeValueDecodable>(
    types: repeat (each T).Type, in context: borrowing JSCallbackContext
  ) throws(JSValueConversionError) -> (repeat each T) {
    var idx = 0
    let pointer = self.pointer
    let globalContextRef = context.globalContextRef
    let nextJSValue: () -> JSValue = {
      defer { idx += 1 }
      let runtimeContext = JSCallbackContext(ctx: globalContextRef)
      if let v = pointer[idx] {
        return JSValue(ref: v, ctx: runtimeContext)
      } else {
        return JSValue(undefinedIn: runtimeContext)
      }
    }
    return
      (repeat try (each T).tryDecode(nextJSValue(), in: context))

  }

  public func unpack<each T: JSValueDecodable>(
    types: repeat (each T).Type, in context: isolated JSContext = #isolation
  ) -> (repeat each T) {
    var idx = 0
    let pointer = self.pointer
    let nextJSValue: () -> JSValue = {
      defer { idx += 1 }
      if let v = pointer[idx] {
        return JSValue(ref: v, ctx: context)
      } else {
        return JSValue(undefinedIn: context)
      }
    }
    return
      (repeat (each T).init(value: nextJSValue(), in: context))

  }

  public func unpack<each T: JSRuntimeValueDecodable>(
    types: repeat (each T).Type, in context: borrowing JSCallbackContext
  ) -> (repeat each T) {
    var idx = 0
    let pointer = self.pointer
    let globalContextRef = context.globalContextRef
    let nextJSValue: () -> JSValue = {
      defer { idx += 1 }
      let runtimeContext = JSCallbackContext(ctx: globalContextRef)
      if let v = pointer[idx] {
        return JSValue(ref: v, ctx: runtimeContext)
      } else {
        return JSValue(undefinedIn: runtimeContext)
      }
    }
    return
      (repeat (each T).init(value: nextJSValue(), in: context))

  }

  public func unpack<C: JSValueDecoder>(
    at: Int,
    using converter: C.Type,
    in context: isolated JSContext = #isolation
  ) -> C.SwiftType {
    unpack(at: at, in: context) { value in
      converter.decode(value, in: context)
    }
  }

  public func unpack<C: JSRuntimeValueDecoder>(
    at: Int,
    using converter: C.Type,
    in context: borrowing JSCallbackContext
  ) -> C.SwiftType {
    unpack(at: at, in: context) { value in
      converter.decode(value, in: context)
    }
  }

  public func tryUnpack<C: JSValueDecoder>(
    at: Int,
    using converter: C.Type,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> C.SwiftType {
    guard at >= 0 && at < count else {
      fatalError("Index out of bounds")
    }
    let value =
      if let v = pointer[at] {
        JSValue(ref: v, ctx: context)
      } else {
        JSValue(undefinedIn: context)
      }
    return try converter.tryDecode(value, in: context)
  }

  public func tryUnpack<C: JSRuntimeValueDecoder>(
    at: Int,
    using converter: C.Type,
    in context: borrowing JSCallbackContext
  ) throws(JSValueConversionError) -> C.SwiftType {
    guard at >= 0 && at < count else {
      fatalError("Index out of bounds")
    }
    let value =
      if let v = pointer[at] {
        JSValue(ref: v, ctx: context)
      } else {
        JSValue(undefinedIn: context)
      }
    return try converter.tryDecode(value, in: context)
  }

  public func unpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: isolated JSContext = #isolation
  ) -> (repeat (each C).SwiftType) {
    var idx = 0
    let pointer = self.pointer
    let nextJSValue: () -> JSValue = {
      defer { idx += 1 }
      if let v = pointer[idx] {
        return JSValue(ref: v, ctx: context)
      } else {
        return JSValue(undefinedIn: context)
      }
    }

    return
      (repeat (each C).decode(nextJSValue(), in: context))
  }

  public func unpack<each C: JSRuntimeValueDecoder>(
    using converters: repeat (each C).Type,
    in context: borrowing JSCallbackContext
  ) -> (repeat (each C).SwiftType) {
    var idx = 0
    let pointer = self.pointer
    let globalContextRef = context.globalContextRef
    let nextJSValue: () -> JSValue = {
      defer { idx += 1 }
      let runtimeContext = JSCallbackContext(ctx: globalContextRef)
      if let v = pointer[idx] {
        return JSValue(ref: v, ctx: runtimeContext)
      } else {
        return JSValue(undefinedIn: runtimeContext)
      }
    }

    return
      (repeat (each C).decode(nextJSValue(), in: context))
  }

  public func tryUnpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: isolated JSContext = #isolation
  ) throws(JSValueConversionError) -> (repeat (each C).SwiftType) {
    var idx = 0
    let pointer = self.pointer
    let nextJSValue: () -> JSValue = {
      defer { idx += 1 }
      if let v = pointer[idx] {
        return JSValue(ref: v, ctx: context)
      } else {
        return JSValue(undefinedIn: context)
      }
    }

    return
      (repeat try (each C).tryDecode(nextJSValue(), in: context))
  }

  public func tryUnpack<each C: JSRuntimeValueDecoder>(
    using converters: repeat (each C).Type,
    in context: borrowing JSCallbackContext
  ) throws(JSValueConversionError) -> (repeat (each C).SwiftType) {
    var idx = 0
    let pointer = self.pointer
    let globalContextRef = context.globalContextRef
    let nextJSValue: () -> JSValue = {
      defer { idx += 1 }
      let runtimeContext = JSCallbackContext(ctx: globalContextRef)
      if let v = pointer[idx] {
        return JSValue(ref: v, ctx: runtimeContext)
      } else {
        return JSValue(undefinedIn: runtimeContext)
      }
    }

    return
      (repeat try (each C).tryDecode(nextJSValue(), in: context))
  }
}
