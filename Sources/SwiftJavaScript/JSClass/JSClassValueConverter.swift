public protocol JSClassValueConvertible: AnyObject {
  associatedtype Engine: JSEngineClassBridgeDriver
  associatedtype ParentClass: Sendable
  associatedtype PropertyNameAccumulator
  associatedtype ClassDefinition: JSClassDefinition
  where
    ClassDefinition.Engine == Engine,
    ClassDefinition.ParentClass == ParentClass,
    ClassDefinition.PropertyNameAccumulator == PropertyNameAccumulator

  static var jsClassDefinition: ClassDefinition { get }

  static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> Self
  where C == Engine.InstantContext

  static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> Self
  where C == Engine.InstantContext

  static func encode<C: JSInstantContext & ~Copyable>(
    _ value: Self,
    in context: borrowing C
  ) -> C.Value
  where C == Engine.InstantContext

  static func tryEncode<C: JSInstantContext & ~Copyable>(
    _ value: Self,
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value
  where C == Engine.InstantContext
}

extension JSClassValueConvertible {
  public static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> Self
  where C == Engine.InstantContext {
    do {
      return try Self.tryDecode(value, in: context)
    } catch {
      fatalError("\(Self.self).decode(_:in:) failed: \(error)")
    }
  }

  public static func encode<C: JSInstantContext & ~Copyable>(
    _ value: Self,
    in context: borrowing C
  ) -> C.Value
  where C == Engine.InstantContext {
    do {
      return try Self.tryEncode(value, in: context)
    } catch {
      return context.persist(context.makeUndefined())
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

/// Adapts a `JSClassValueConvertible` to the surface conversion shape.
///
/// The surface converter protocols (`JSValueDecoder`/
/// `JSValueEncoder`) are engine-agnostic: their generic context is any
/// `JSInstantContext`. Class conversion is engine-bound (`T.Engine`), so this
/// adapter keeps the surface parameter shape and states the engine equality on
/// each method instead of declaring an unsatisfiable conformance. No handle is
/// cast across engines.
public enum JSClassValueConverter<T: JSClassValueConvertible> {
  public typealias SwiftType = T

  public static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> T
  where C == T.Engine.InstantContext {
    T.decode(value, in: context)
  }

  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> T
  where C == T.Engine.InstantContext {
    try T.tryDecode(value, in: context)
  }

  public static func encode<C: JSInstantContext & ~Copyable>(
    _ value: T,
    in context: borrowing C
  ) -> C.Value
  where C == T.Engine.InstantContext {
    T.encode(value, in: context)
  }

  public static func tryEncode<C: JSInstantContext & ~Copyable>(
    _ value: T,
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value
  where C == T.Engine.InstantContext {
    try T.tryEncode(value, in: context)
  }
}
