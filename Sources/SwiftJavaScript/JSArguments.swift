public struct JSArguments<E: JSEngine>: ~Copyable {
  public let count: Int
  private let valueHandleAt: (Int, E.ContextHandle) -> JSValueHandle<E>?

  public init(
    count: Int,
    valueHandleAt: @escaping (Int, E.ContextHandle) -> JSValueHandle<E>?
  ) {
    self.count = count
    self.valueHandleAt = valueHandleAt
  }

  @inline(__always)
  private func value(at index: Int, in context: borrowing JSEngineInstantContext<E>)
    -> JSValue<E>
  {
    guard index >= 0 && index < count else {
      fatalError("Index out of bounds")
    }

    if let handle = valueHandleAt(index, context.driverContextHandle) {
      return JSValue(handleValue: handle)
    }

    return context.makeUndefined()
  }

  public func unpack<R: ~Copyable>(
    at: Int,
    in context: borrowing JSEngineInstantContext<E>,
    _ body: (borrowing JSValue<E>) -> R
  ) -> R {
    body(value(at: at, in: context))
  }

  public func unpack<R: ~Copyable>(
    at: Int,
    in context: isolated JSEngineContext<E> = #isolation,
    _ body: (borrowing JSValue<E>) -> R
  ) -> R {
    context.withInstantContext { callbackContext in
      unpack(at: at, in: callbackContext, body)
    }
  }
}

extension JSArguments {
  @inline(__always)
  private func nextValue(_ index: inout Int, in context: borrowing JSEngineInstantContext<E>)
    -> JSValue<E>
  {
    defer { index += 1 }
    return value(at: index, in: context)
  }

  public func tryUnpack<each T: JSValueDecodable>(
    types: repeat (each T).Type,
    in context: borrowing JSEngineInstantContext<E>
  ) throws(JSValueConversionError) -> (repeat each T) {
    var idx = 0
    return (repeat try (each T).tryDecode(nextValue(&idx, in: context), in: context))
  }

  public func tryUnpack<each T: JSValueDecodable>(
    types: repeat (each T).Type,
    in context: isolated JSEngineContext<E> = #isolation
  ) throws(JSValueConversionError) -> (repeat each T) {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try tryUnpack(types: repeat (each T).self, in: callbackContext)
    }
  }

  public func unpack<each T: JSValueDecodable>(
    types: repeat (each T).Type,
    in context: borrowing JSEngineInstantContext<E>
  ) -> (repeat each T) {
    var idx = 0
    return (repeat (each T).init(value: nextValue(&idx, in: context), in: context))
  }

  public func unpack<each T: JSValueDecodable>(
    types: repeat (each T).Type,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> (repeat each T) {
    context.withInstantContext { callbackContext in
      unpack(types: repeat (each T).self, in: callbackContext)
    }
  }

  public func unpack<C: JSValueDecoder>(
    at: Int,
    using converter: C.Type,
    in context: borrowing JSEngineInstantContext<E>
  ) -> C.SwiftType {
    unpack(at: at, in: context) { value in
      converter.decode(value, in: context)
    }
  }

  public func unpack<C: JSValueDecoder>(
    at: Int,
    using converter: C.Type,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> C.SwiftType {
    context.withInstantContext { callbackContext in
      unpack(at: at, using: converter, in: callbackContext)
    }
  }

  public func tryUnpack<C: JSValueDecoder>(
    at: Int,
    using converter: C.Type,
    in context: borrowing JSEngineInstantContext<E>
  ) throws(JSValueConversionError) -> C.SwiftType {
    try converter.tryDecode(value(at: at, in: context), in: context)
  }

  public func tryUnpack<C: JSValueDecoder>(
    at: Int,
    using converter: C.Type,
    in context: isolated JSEngineContext<E> = #isolation
  ) throws(JSValueConversionError) -> C.SwiftType {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try tryUnpack(at: at, using: converter, in: callbackContext)
    }
  }

  public func unpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: borrowing JSEngineInstantContext<E>
  ) -> (repeat (each C).SwiftType) {
    var idx = 0
    return (repeat (each C).decode(nextValue(&idx, in: context), in: context))
  }

  public func unpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: isolated JSEngineContext<E> = #isolation
  ) -> (repeat (each C).SwiftType) {
    context.withInstantContext { callbackContext in
      unpack(using: repeat (each C).self, in: callbackContext)
    }
  }

  public func tryUnpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: borrowing JSEngineInstantContext<E>
  ) throws(JSValueConversionError) -> (repeat (each C).SwiftType) {
    var idx = 0
    return (repeat try (each C).tryDecode(nextValue(&idx, in: context), in: context))
  }

  public func tryUnpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: isolated JSEngineContext<E> = #isolation
  ) throws(JSValueConversionError) -> (repeat (each C).SwiftType) {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try tryUnpack(using: repeat (each C).self, in: callbackContext)
    }
  }
}
