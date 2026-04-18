public struct JSArguments<E: JSEngine>: ~Copyable {
  public let count: Int
  private let borrowsValueHandles: Bool
  private let valueHandleAt: (Int, E.ContextHandle) -> JSValueHandle<E>?

  public init(
    count: Int,
    valueHandleAt: @escaping (Int, E.ContextHandle) -> JSValueHandle<E>?
  ) {
    self.init(
      count: count,
      borrowsValueHandles: false,
      valueHandleAt: valueHandleAt
    )
  }

  public init(
    count: Int,
    borrowsValueHandles: Bool,
    valueHandleAt: @escaping (Int, E.ContextHandle) -> JSValueHandle<E>?
  ) {
    self.count = count
    self.borrowsValueHandles = borrowsValueHandles
    self.valueHandleAt = valueHandleAt
  }

  @inline(__always)
  private func value(at index: Int, in context: borrowing JSInstantContext<E>)
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

  @inline(__always)
  private func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing JSInstantContext<E>,
    _ body: (borrowing JSValue<E>) -> R
  ) -> R {
    if borrowsValueHandles {
      let value = value(at: index, in: context)
      let result = body(value)
      // Borrowed callback arguments are owned by the engine call frame.
      // Discard the Swift wrapper without running JSValue.deinit/releaseReference.
      value.discard()
      return result
    }
    return body(value(at: index, in: context))
  }

  @inline(__always)
  private func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing JSInstantContext<E>,
    _ body: (borrowing JSValue<E>) throws(JSValueConversionError) -> R
  ) throws(JSValueConversionError) -> R {
    if borrowsValueHandles {
      let value = value(at: index, in: context)
      do {
        let result = try body(value)
        // Borrowed callback arguments are owned by the engine call frame.
        // Discard the Swift wrapper without running JSValue.deinit/releaseReference.
        value.discard()
        return result
      } catch {
        // Keep the borrow balanced even when decoding throws.
        value.discard()
        throw error
      }
    }
    return try body(value(at: index, in: context))
  }

  public func unpack<R: ~Copyable>(
    at: Int,
    in context: borrowing JSInstantContext<E>,
    _ body: (borrowing JSValue<E>) -> R
  ) -> R {
    withValue(at: at, in: context, body)
  }

  public func unpack<R: ~Copyable>(
    at: Int,
    in context: isolated JSContext<E> = #isolation,
    _ body: (borrowing JSValue<E>) -> R
  ) -> R {
    context.withInstantContext { callbackContext in
      unpack(at: at, in: callbackContext, body)
    }
  }
}

extension JSArguments {
  @inline(__always)
  private func unpackNext<T: JSValueDecodable>(
    _ index: inout Int,
    type: T.Type,
    in context: borrowing JSInstantContext<E>
  ) -> T {
    defer { index += 1 }
    return withValue(at: index, in: context) { value in
      T(value: value, in: context)
    }
  }

  @inline(__always)
  private func tryUnpackNext<T: JSValueDecodable>(
    _ index: inout Int,
    type: T.Type,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> T {
    defer { index += 1 }
    return try withValue(at: index, in: context) { value throws(JSValueConversionError) in
      try T.tryDecode(value, in: context)
    }
  }

  @inline(__always)
  private func unpackNext<C: JSValueDecoder>(
    _ index: inout Int,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) -> C.SwiftType {
    defer { index += 1 }
    return withValue(at: index, in: context) { value in
      C.decode(value, in: context)
    }
  }

  @inline(__always)
  private func tryUnpackNext<C: JSValueDecoder>(
    _ index: inout Int,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> C.SwiftType {
    defer { index += 1 }
    return try withValue(at: index, in: context) { value throws(JSValueConversionError) in
      try C.tryDecode(value, in: context)
    }
  }

  public func tryUnpack<each T: JSValueDecodable>(
    types: repeat (each T).Type,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> (repeat each T) {
    var idx = 0
    return (repeat try tryUnpackNext(&idx, type: (each T).self, in: context))
  }

  public func tryUnpack<each T: JSValueDecodable>(
    types: repeat (each T).Type,
    in context: isolated JSContext<E> = #isolation
  ) throws(JSValueConversionError) -> (repeat each T) {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try tryUnpack(types: repeat (each T).self, in: callbackContext)
    }
  }

  public func unpack<each T: JSValueDecodable>(
    types: repeat (each T).Type,
    in context: borrowing JSInstantContext<E>
  ) -> (repeat each T) {
    var idx = 0
    return (repeat unpackNext(&idx, type: (each T).self, in: context))
  }

  public func unpack<each T: JSValueDecodable>(
    types: repeat (each T).Type,
    in context: isolated JSContext<E> = #isolation
  ) -> (repeat each T) {
    context.withInstantContext { callbackContext in
      unpack(types: repeat (each T).self, in: callbackContext)
    }
  }

  public func unpack<C: JSValueDecoder>(
    at: Int,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) -> C.SwiftType {
    unpack(at: at, in: context) { value in
      converter.decode(value, in: context)
    }
  }

  public func unpack<C: JSValueDecoder>(
    at: Int,
    using converter: C.Type,
    in context: isolated JSContext<E> = #isolation
  ) -> C.SwiftType {
    context.withInstantContext { callbackContext in
      unpack(at: at, using: converter, in: callbackContext)
    }
  }

  public func tryUnpack<C: JSValueDecoder>(
    at: Int,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> C.SwiftType {
    try withValue(at: at, in: context) { value throws(JSValueConversionError) in
      try converter.tryDecode(value, in: context)
    }
  }

  public func tryUnpack<C: JSValueDecoder>(
    at: Int,
    using converter: C.Type,
    in context: isolated JSContext<E> = #isolation
  ) throws(JSValueConversionError) -> C.SwiftType {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try tryUnpack(at: at, using: converter, in: callbackContext)
    }
  }

  public func unpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: borrowing JSInstantContext<E>
  ) -> (repeat (each C).SwiftType) {
    var idx = 0
    return (repeat unpackNext(&idx, using: (each C).self, in: context))
  }

  public func unpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: isolated JSContext<E> = #isolation
  ) -> (repeat (each C).SwiftType) {
    context.withInstantContext { callbackContext in
      unpack(using: repeat (each C).self, in: callbackContext)
    }
  }

  public func tryUnpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> (repeat (each C).SwiftType) {
    var idx = 0
    return (repeat try tryUnpackNext(&idx, using: (each C).self, in: context))
  }

  public func tryUnpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: isolated JSContext<E> = #isolation
  ) throws(JSValueConversionError) -> (repeat (each C).SwiftType) {
    try context.withInstantContext { callbackContext throws(JSValueConversionError) in
      try tryUnpack(using: repeat (each C).self, in: callbackContext)
    }
  }
}
