/// Borrowed JavaScript function call arguments.
public struct JSCallbackArguments<E: JSEngine>: ~Copyable {
  public let count: Int
  private let borrowedValueHandleAt: (Int) -> JSValueHandle<E>?

  public init(
    count: Int,
    borrowedValueHandleAt: @escaping (Int) -> JSValueHandle<E>?
  ) {
    self.count = count
    self.borrowedValueHandleAt = borrowedValueHandleAt
  }

  /// Access a borrowed `JSCallbackValue` at the given index.
  @inline(__always)
  public func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing JSInstantContext<E>,
    _ body: (borrowing JSCallbackValue<E>) -> R
  ) -> R {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let handle = borrowedValueHandleAt(index) else {
      fatalError("JSArgument handle is unavailable")
    }
    let val = JSCallbackValue<E>(handle: handle)
    return body(val)
  }
}

// MARK: - Unpacking (via scope.decode)

extension JSCallbackArguments {
  @inline(__always)
  private func unpackNext<T: JSValueDecodable>(
    _ index: inout Int,
    type: T.Type,
    in context: borrowing JSInstantContext<E>
  ) -> T {
    defer { index += 1 }
    return withValue(at: index, in: context) { val in
      val.decode(as: T.self)
    }
  }

  @inline(__always)
  private func tryUnpackNext<T: JSValueDecodable>(
    _ index: inout Int,
    type: T.Type,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> T {
    defer { index += 1 }
    return try _withThrowingValue(at: index, in: context) { val throws(JSValueConversionError) in
      try T.tryDecode(
        JSValue<E>(handleValue: val.handle, in: context.driverContextHandle), in: context)
    }
  }

  @inline(__always)
  private func _withThrowingValue<T>(
    at index: Int,
    in context: borrowing JSInstantContext<E>,
    _ body: (borrowing JSCallbackValue<E>) throws(JSValueConversionError) -> T
  ) throws(JSValueConversionError) -> T {
    guard index >= 0, index < count else {
      fatalError("Index out of bounds")
    }
    guard let handle = borrowedValueHandleAt(index) else {
      fatalError("JSArgument handle is unavailable")
    }
    let val = JSCallbackValue<E>(handle: handle)
    return try body(val)
  }

  // ---- variadic ----

  /// Unpack all arguments as the given types (non-throwing).
  public func unpack<each T: JSValueDecodable>(
    types: repeat (each T).Type,
    in context: borrowing JSInstantContext<E>
  ) -> (repeat each T) {
    var idx = 0
    return (repeat unpackNext(&idx, type: (each T).self, in: context))
  }

  /// Try-unpack all arguments as the given types.
  public func tryUnpack<each T: JSValueDecodable>(
    types: repeat (each T).Type,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> (repeat each T) {
    var idx = 0
    return (repeat try tryUnpackNext(&idx, type: (each T).self, in: context))
  }

  // ---- converter-based unpacking ----

  @inline(__always)
  private func unpackNext<C: JSValueDecoder>(
    _ index: inout Int,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) -> C.SwiftType {
    defer { index += 1 }
    return withValue(at: index, in: context) { val in
      C.decode(
        JSValue<E>(handleValue: val.handle, in: context.driverContextHandle),
        in: context
      )
    }
  }

  @inline(__always)
  private func tryUnpackNext<C: JSValueDecoder>(
    _ index: inout Int,
    using converter: C.Type,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> C.SwiftType {
    defer { index += 1 }
    return try _withThrowingValue(at: index, in: context) { val throws(JSValueConversionError) in
      try C.tryDecode(
        JSValue<E>(handleValue: val.handle, in: context.driverContextHandle), in: context)
    }
  }

  public func tryUnpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> (repeat (each C).SwiftType) {
    var idx = 0
    return (repeat try tryUnpackNext(&idx, using: (each C).self, in: context))
  }

  public func unpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: borrowing JSInstantContext<E>
  ) -> (repeat (each C).SwiftType) {
    var idx = 0
    return (repeat unpackNext(&idx, using: (each C).self, in: context))
  }
}
