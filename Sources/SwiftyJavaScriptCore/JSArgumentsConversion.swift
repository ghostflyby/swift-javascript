extension JSArguments {
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

  public func unpack<C: JSValueConverter>(
    at: Int,
    using converter: C.Type,
    in context: isolated JSContext = #isolation
  ) -> C.SwiftType {
    unpack(at: at, in: context) { value in
      converter.decode(value, in: context)
    }
  }

  public func unpack<each C: JSValueConverter>(
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
}
