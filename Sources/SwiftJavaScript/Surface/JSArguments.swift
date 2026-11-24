/// Borrowed JavaScript function call arguments, viewed as local values.
///
/// The element view type is the engine's `Value`; the concrete argument type
/// decides how the engine exposes the call frame's borrowed handles.
public protocol JSArguments: ~Copyable {
  /// The context this argument view belongs to.
  associatedtype Context: JSContext
  associatedtype Value: JSValue & ~Copyable
  where Value == Context.Value
  /// The scope arguments are decoded in.
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext == Context.InstantContext

  var count: Int { get }

  /// Access the borrowed argument at `index` as the engine's local value view.
  func withValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing InstantContext,
    _ body: (borrowing Value) -> R
  ) -> R

  /// Throwing counterpart of `withValue`; conversion failures surface as
  /// `JSValueConversionError`. Macro-generated method bodies decode each
  /// argument through this entry.
  func withThrowingValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing InstantContext,
    _ body: (borrowing Value) throws(JSValueConversionError) -> R
  ) throws(JSValueConversionError) -> R
}

// Variadic decoding is engine-agnostic: it only needs the `withValue` primitive
// and the surface decoder contract. Written as `extension where Self:
// ~Copyable` so noncopyable argument views get the defaults without an
// explicit conformance to a separate helper protocol.
extension JSArguments where Self: ~Copyable {
  /// Default throwing access: run `withValue` and carry the conversion error
  /// out of its non-throwing body.
  public func withThrowingValue<R: ~Copyable>(
    at index: Int,
    in context: borrowing InstantContext,
    _ body: (borrowing Value) throws(JSValueConversionError) -> R
  ) throws(JSValueConversionError) -> R {
    var failure: JSValueConversionError? = nil
    var result: R? = nil
    withValue(at: index, in: context) { value in
      do {
        result = try body(value)
      } catch let error as JSValueConversionError {
        failure = error
      } catch {
        preconditionFailure("JSArguments.withThrowingValue decoded with an unexpected error")
      }
    }
    if let failure {
      throw failure
    }
    guard let result else {
      preconditionFailure("JSArguments.withThrowingValue decoded no value")
    }
    return result
  }

  /// Unpack all arguments as the given types (non-throwing).
  public func unpack<each T: JSValueDecodable>(
    types: repeat (each T).Type,
    in context: borrowing InstantContext
  ) -> (repeat each T) {
    var index = 0
    return (repeat unpackNext(&index, type: (each T).self, in: context))
  }

  /// Try-unpack all arguments as the given types.
  public func tryUnpack<each T: JSValueDecodable>(
    types: repeat (each T).Type,
    in context: borrowing InstantContext
  ) throws(JSValueConversionError) -> (repeat each T) {
    var index = 0
    return (repeat try tryUnpackNext(&index, type: (each T).self, in: context))
  }

  /// Unpack all arguments through the given converters.
  public func unpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: borrowing InstantContext
  ) -> (repeat (each C).SwiftType) {
    var index = 0
    return (repeat unpackNext(&index, using: (each C).self, in: context))
  }

  /// Try-unpack all arguments through the given converters.
  public func tryUnpack<each C: JSValueDecoder>(
    using converters: repeat (each C).Type,
    in context: borrowing InstantContext
  ) throws(JSValueConversionError) -> (repeat (each C).SwiftType) {
    var index = 0
    return (repeat try tryUnpackNext(&index, using: (each C).self, in: context))
  }

  @inline(__always)
  private func unpackNext<T: JSValueDecodable>(
    _ index: inout Int,
    type: T.Type,
    in context: borrowing InstantContext
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
    in context: borrowing InstantContext
  ) throws(JSValueConversionError) -> T {
    defer { index += 1 }
    var failure: JSValueConversionError? = nil
    var decoded: T? = nil
    withValue(at: index, in: context) { value in
      do {
        decoded = try T.tryDecode(value, in: context)
      } catch let error as JSValueConversionError {
        failure = error
      } catch {
        preconditionFailure("JSArguments.tryUnpack decoded with an unexpected error")
      }
    }
    if let failure {
      throw failure
    }
    guard let decoded else {
      preconditionFailure("JSArguments.tryUnpack decoded no value")
    }
    return decoded
  }

  @inline(__always)
  private func unpackNext<C: JSValueDecoder>(
    _ index: inout Int,
    using converter: C.Type,
    in context: borrowing InstantContext
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
    in context: borrowing InstantContext
  ) throws(JSValueConversionError) -> C.SwiftType {
    defer { index += 1 }
    var failure: JSValueConversionError? = nil
    var decoded: C.SwiftType? = nil
    withValue(at: index, in: context) { value in
      do {
        decoded = try C.tryDecode(value, in: context)
      } catch let error as JSValueConversionError {
        failure = error
      } catch {
        preconditionFailure("JSArguments.tryUnpack decoded with an unexpected error")
      }
    }
    if let failure {
      throw failure
    }
    guard let decoded else {
      preconditionFailure("JSArguments.tryUnpack decoded no value")
    }
    return decoded
  }
}
