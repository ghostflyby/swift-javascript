public protocol JSClassValueConvertible: AnyObject {
  associatedtype Context: JSContext
  associatedtype ParentClass: Sendable
  associatedtype PropertyNameAccumulator
  associatedtype ClassDefinition: JSClassDefinition
  where
    ClassDefinition.Context == Context,
    ClassDefinition.ParentClass == ParentClass,
    ClassDefinition.PropertyNameAccumulator == PropertyNameAccumulator

  static var jsClassDefinition: ClassDefinition { get }

  static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> Self
  where C == Context.InstantContext

  static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> Self
  where C == Context.InstantContext

  static func encode<C: JSInstantContext & ~Copyable>(
    _ value: Self,
    in context: borrowing C
  ) -> C.Value
  where C == Context.InstantContext

  static func tryEncode<C: JSInstantContext & ~Copyable>(
    _ value: Self,
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value
  where C == Context.InstantContext
}

extension JSClassValueConvertible {
  public static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> Self
  where C == Context.InstantContext {
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
  where C == Context.InstantContext {
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

extension JSClassValueConvertible
where
  ParentClass == JSClassParentDescriptor<Context, Context.ClassPropertyNameAccumulator>,
  PropertyNameAccumulator == Context.ClassPropertyNameAccumulator,
  ClassDefinition == JSEngineClassDefinition<
    Context,
    JSClassParentDescriptor<Context, Context.ClassPropertyNameAccumulator>,
    Context.ClassPropertyNameAccumulator
  >
{
  /// The engine class backing this Swift type in `context`'s runtime.
  public static func jsClass(in context: borrowing Context.InstantContext) -> Context.Class {
    context.makeClass(
      definition: Self.autoClassDefinition(),
      identity: ObjectIdentifier(Self.self)
    )
  }

  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> Self
  where C == Context.InstantContext {
    let valueType = value.type()
    guard valueType == .object else {
      throw .typeMismatch(expected: "object", actual: valueType)
    }

    guard let privateData = context.hostObjectPrivateData(of: value) else {
      throw .codable("\(Self.self) does not have a Swift instance backing")
    }

    let storage = Unmanaged<JSClassAutoObjectStorage<ClassDefinition>>
      .fromOpaque(privateData)
      .takeUnretainedValue()
    guard let instance = storage.typedInstance(as: Self.self) else {
      throw .codable("JS object backing is not of type \(Self.self)")
    }

    return instance
  }

  public static func tryEncode<C: JSInstantContext & ~Copyable>(
    _ value: Self,
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value
  where C == Context.InstantContext {
    let storage = Self.autoObjectStorage(
      instance: value,
      lookup: JSClassDefinitionLookup { parentClass in
        parentClass.definition()
      }
    )
    let privateData = Unmanaged.passRetained(storage).toOpaque()

    guard
      let object = context.makeHostObject(
        of: Self.jsClass(in: context),
        privateData: privateData
      )
    else {
      // `makeHostObject` returning nil means the engine already settled the
      // failure path's references; the Swift storage is still ours.
      _ = Unmanaged<JSClassAutoObjectStorage<ClassDefinition>>
        .fromOpaque(privateData)
        .takeRetainedValue()
      throw .codable("Failed to create JS object for \(Self.self)")
    }
    return object
  }
}

/// Adapts a `JSClassValueConvertible` to the surface conversion shape.
///
/// The surface converter protocols (`JSValueDecoder`/
/// `JSValueEncoder`) are engine-agnostic: their generic context is any
/// `JSInstantContext`. Class conversion is engine-bound (`T.Context`), so this
/// adapter keeps the surface parameter shape and states the engine equality on
/// each method instead of declaring an unsatisfiable conformance. No handle is
/// cast across engines.
public enum JSClassValueConverter<T: JSClassValueConvertible> {
  public typealias SwiftType = T

  public static func decode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) -> T
  where C == T.Context.InstantContext {
    T.decode(value, in: context)
  }

  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> T
  where C == T.Context.InstantContext {
    try T.tryDecode(value, in: context)
  }

  public static func encode<C: JSInstantContext & ~Copyable>(
    _ value: T,
    in context: borrowing C
  ) -> C.Value
  where C == T.Context.InstantContext {
    T.encode(value, in: context)
  }

  public static func tryEncode<C: JSInstantContext & ~Copyable>(
    _ value: T,
    in context: borrowing C
  ) throws(JSValueConversionError) -> C.Value
  where C == T.Context.InstantContext {
    try T.tryEncode(value, in: context)
  }
}
