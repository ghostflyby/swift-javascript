/// Engine-side class bridge: what the shared class definition, storage and
/// lookup templates need from an engine — the value-level statics that create
/// classes and host objects, plus the engine's value, scope, argument and
/// class types (aliases of its context's). No value-side protocol refers to
/// it, and no handle type appears on its surface.
public protocol JSEngineClassBridgeDriver: Sendable {
  /// The context type this engine's host objects live in.
  associatedtype Context: JSContext
  associatedtype Value: JSValue & ~Copyable
  where Value == Context.Value
  associatedtype InstantContext: JSInstantContext & ~Copyable
  where InstantContext == Context.InstantContext
  associatedtype Arguments: JSArguments & ~Copyable
  where Arguments == Context.Arguments
  associatedtype Class: JSClass
  where Class == Context.Class
  associatedtype ClassPropertyNameAccumulator

  /// Get or create this engine's class for `identity`. The cache key is
  /// `(identity, context's runtime)`: one Swift type reuses one engine class
  /// per runtime.
  static func makeClass(
    definition: JSEngineClassDefinition<
      Self,
      JSClassParentDescriptor<Self, ClassPropertyNameAccumulator>,
      ClassPropertyNameAccumulator
    >,
    identity: ObjectIdentifier,
    in context: borrowing InstantContext
  ) -> Class

  /// Create a host object for `jsClass`, adopting its creation reference onto
  /// `context`'s synchronous window arena. `nil` means the engine settled the
  /// failure path's reference itself.
  static func makeHostObject(
    of jsClass: Class,
    privateData: UnsafeMutableRawPointer,
    in context: borrowing InstantContext
  ) -> Value?

  /// Read the Swift-side private data of a host object. `nil` means the value
  /// was not created by this engine's class system.
  static func hostObjectPrivateData(
    of value: borrowing Value,
    in context: borrowing InstantContext
  ) -> UnsafeMutableRawPointer?
}

extension JSClassValueConvertible
where
  Engine: JSEngineClassBridgeDriver,
  ParentClass == JSClassParentDescriptor<Engine, Engine.ClassPropertyNameAccumulator>,
  PropertyNameAccumulator == Engine.ClassPropertyNameAccumulator,
  ClassDefinition == JSEngineClassDefinition<
    Engine,
    JSClassParentDescriptor<Engine, Engine.ClassPropertyNameAccumulator>,
    Engine.ClassPropertyNameAccumulator
  >
{
  public static func jsClass(in context: borrowing Engine.InstantContext) -> Engine.Class {
    Engine.makeClass(
      definition: Self.autoClassDefinition(),
      identity: ObjectIdentifier(Self.self),
      in: context
    )
  }

  public static func tryDecode<C: JSInstantContext & ~Copyable>(
    _ value: borrowing C.Value,
    in context: borrowing C
  ) throws(JSValueConversionError) -> Self
  where C == Engine.InstantContext {
    let valueType = value.type()
    guard valueType == .object else {
      throw .typeMismatch(expected: "object", actual: valueType)
    }

    guard let privateData = Engine.hostObjectPrivateData(of: value, in: context) else {
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
  where C == Engine.InstantContext {
    let storage = Self.autoObjectStorage(
      instance: value,
      lookup: JSClassDefinitionLookup { parentClass in
        parentClass.definition()
      }
    )
    let privateData = Unmanaged.passRetained(storage).toOpaque()

    guard
      let object = Engine.makeHostObject(
        of: Self.jsClass(in: context),
        privateData: privateData,
        in: context
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
