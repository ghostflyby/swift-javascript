public protocol JSClassValueConvertible: AnyObject, JSValueEncodable {
  associatedtype Engine: JSEngine
  associatedtype ParentClass: Sendable
  associatedtype PropertyNameAccumulator
  associatedtype ClassDefinition: JSClassDefinition
  where
    ClassDefinition.Engine == Engine,
    ClassDefinition.ParentClass == ParentClass,
    ClassDefinition.PropertyNameAccumulator == PropertyNameAccumulator

  static var jsClassDefinition: ClassDefinition { get }

  static func decode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Self

  static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> Self

  static func encode<E: JSValueConversionEngine>(
    _ value: Self,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E>

  static func tryEncode<E: JSValueConversionEngine>(
    _ value: Self,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E>
}

extension JSClassValueConvertible {
  public static func decode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> Self {
    do {
      return try Self.tryDecode(value, in: context)
    } catch {
      fatalError("\(Self.self).decode(_:in:) failed: \(error)")
    }
  }

  public static func encode<E: JSValueConversionEngine>(
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

extension JSClassValueConvertible {
  package static func autoClassDefinition() -> ClassDefinition {
    jsClassDefinition
  }

  package static func autoNativeClassBacking<NativeStaticValue, NativeStaticFunction>(
    lookup: JSClassDefinitionLookup<ClassDefinition>
  ) -> JSClassAutoNativeClassBacking<
    ClassDefinition,
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
    lookup: JSClassDefinitionLookup<ClassDefinition>
  ) -> JSClassAutoObjectStorage<ClassDefinition> {
    JSClassAutoObjectStorage(
      definition: autoClassDefinition(),
      instance: instance,
      lookup: lookup
    )
  }

}

public enum JSClassValueConverter<T: JSClassValueConvertible>: JSValueConverter {
  public typealias SwiftType = T

  public static func decode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) -> T {
    T.decode(value, in: context)
  }

  public static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> T {
    try T.tryDecode(value, in: context)
  }

  public static func encode<E: JSValueConversionEngine>(
    _ value: T,
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    T.encode(value, in: context)
  }

  public static func tryEncode<E: JSValueConversionEngine>(
    _ value: T,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    try T.tryEncode(value, in: context)
  }
}
