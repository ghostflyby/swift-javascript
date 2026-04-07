public protocol JSClassValueConverterCompatible: AnyObject, JSValueEncodable {
  associatedtype Engine: JSEngine
  associatedtype ParentClass: Sendable
  associatedtype PropertyNameAccumulator

  static var jsClassDefinition: JSClassDefinition<Engine, ParentClass, PropertyNameAccumulator> {
    get
  }

  static func decode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Self

  static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> Self

  static func encode<E: JSEngine>(
    _ value: Self,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E>

  static func tryEncode<E: JSEngine>(
    _ value: Self,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E>
}

extension JSClassValueConverterCompatible {
  public static func decode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Self {
    do {
      return try Self.tryDecode(value, in: context)
    } catch {
      fatalError("\(Self.self).decode(_:in:) failed: \(error)")
    }
  }

  public static func encode<E: JSEngine>(
    _ value: Self,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    do {
      return try Self.tryEncode(value, in: context)
    } catch {
      return JSValue<E>(undefinedIn: context)
    }
  }
}

extension JSClassValueConverterCompatible {
  package static func autoClassDefinition() -> JSClassDefinition<
    Engine, ParentClass, PropertyNameAccumulator
  > {
    jsClassDefinition
  }

  package static func autoNativeClassBacking<NativeStaticValue, NativeStaticFunction>(
    lookup: JSClassDefinitionLookup<Engine, ParentClass, PropertyNameAccumulator>
  ) -> JSClassAutoNativeClassBacking<
    Engine,
    ParentClass,
    PropertyNameAccumulator,
    NativeStaticValue,
    NativeStaticFunction
  > {
    JSClassAutoNativeClassBacking(
      definition: autoClassDefinition(),
      lookup: lookup
    )
  }

  package static func autoObjectStorage(
    instance: Self,
    lookup: JSClassDefinitionLookup<Engine, ParentClass, PropertyNameAccumulator>
  ) -> JSClassAutoObjectStorage<Engine, ParentClass, PropertyNameAccumulator> {
    JSClassAutoObjectStorage(
      definition: autoClassDefinition(),
      instance: instance,
      lookup: lookup
    )
  }
}

public enum JSClassValueConverter<T: JSClassValueConverterCompatible>: JSValueConverter {
  public typealias SwiftType = T

  public static func decode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> T {
    T.decode(value, in: context)
  }

  public static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> T {
    try T.tryDecode(value, in: context)
  }

  public static func encode<E: JSEngine>(
    _ value: T,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    T.encode(value, in: context)
  }

  public static func tryEncode<E: JSEngine>(
    _ value: T,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    try T.tryEncode(value, in: context)
  }
}
