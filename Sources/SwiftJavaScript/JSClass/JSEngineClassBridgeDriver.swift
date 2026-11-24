/// Engine-side class bridge: what the shared class definition, storage and
/// lookup templates need from an engine — the statics that create classes and
/// host objects, plus the engine's value, scope, argument and class types
/// (aliases of its context's). No value-side protocol refers to it.
public protocol JSEngineClassBridgeDriver: JSEngineRuntimeDriver
where
  ContextHandle == Context.ContextHandle,
  ClassHandle == Context.ClassHandle,
  RuntimeHandle: Hashable
{
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

  static func makeClass(
    definition: JSEngineClassDefinition<
      Self,
      JSClassParentDescriptor<Self, ClassPropertyNameAccumulator>,
      ClassPropertyNameAccumulator
    >,
    in runtime: RuntimeHandle
  ) -> Class

  static func runtimeHandle(for context: ContextHandle) -> RuntimeHandle?

  static func makeClassObjectResultHandle(
    of jsClass: Class,
    privateData: UnsafeMutableRawPointer,
    in context: ContextHandle
  ) -> JSResult<ValueHandle>?

  static func classObjectPrivateData(
    from value: ValueHandle,
    in context: ContextHandle
  ) -> JSResult<UnsafeMutableRawPointer?>?
}

private final class JSClassValueConvertibleClassBox: @unchecked Sendable {
  let value: AnyObject

  init(_ value: AnyObject) {
    self.value = value
  }
}

private struct JSClassValueConvertibleRegistryKey: Hashable, @unchecked Sendable {
  let typeID: ObjectIdentifier
  let runtime: AnyHashable
}

private let jsClassValueConvertibleRegistry =
  JSClassMapRegistry<JSClassValueConvertibleRegistryKey, JSClassValueConvertibleClassBox>()

package func removeJSClassValueConvertibleClasses<E: JSEngineClassBridgeDriver>(
  for engine: E.Type,
  in runtime: E.RuntimeHandle
) {
  _ = engine
  let erasedRuntime = AnyHashable(runtime)
  _ = jsClassValueConvertibleRegistry.removeValues {
    $0.runtime == erasedRuntime
  }
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
  public static func jsClass(in runtime: Engine.RuntimeHandle) -> Engine.Class {
    let key = JSClassValueConvertibleRegistryKey(
      typeID: ObjectIdentifier(Self.self),
      runtime: AnyHashable(runtime)
    )
    let boxed = jsClassValueConvertibleRegistry.value(forKey: key) {
      JSClassValueConvertibleClassBox(
        Engine.makeClass(definition: Self.autoClassDefinition(), in: runtime)
      )
    }
    return boxed.value as! Engine.Class
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

    let privateData: UnsafeMutableRawPointer?
    switch Engine.classObjectPrivateData(
      from: value.borrowHandle(), in: context.driverContextHandle)
    {
    case .value(let data):
      privateData = data
    case .exception:
      throw .codable("\(Self.self) could not be converted to a host object")
    case nil:
      throw .codable("\(Self.self) could not read host object storage")
    }

    guard let privateData else {
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
    guard let runtime = Engine.runtimeHandle(for: context.driverContextHandle) else {
      throw .codable("Could not resolve runtime for \(Engine.self) context")
    }
    let storage = Self.autoObjectStorage(
      instance: value,
      lookup: JSClassDefinitionLookup { parentClass in
        parentClass.definition()
      }
    )
    let privateData = Unmanaged.passRetained(storage).toOpaque()

    switch Engine.makeClassObjectResultHandle(
      of: Self.jsClass(in: runtime),
      privateData: privateData,
      in: context.driverContextHandle
    ) {
    case .value(let object):
      // The host object belongs to the encoding scope's synchronous window:
      // its creation reference is settled when that scope drains. Anchoring
      // on the context default scope instead would keep the object alive (and
      // its finalizer unfired) until the context dies, even after JavaScript
      // drops every reference to it.
      return context.adoptCreatedHandle(Engine.OwnedValueHandle.adopting(object))
    case .exception(let exception):
      // The creation result carries an owned reference on the failure path
      // too (QuickJS: `JS_GetException` returns +1). The conversion error
      // does not expose the JS value, so settle the reference before
      // throwing instead of dropping the handle.
      context.driverContextHandle.releaseCreatedHandle(
        Engine.OwnedValueHandle.adopting(exception)
      )
      _ = Unmanaged<JSClassAutoObjectStorage<ClassDefinition>>
        .fromOpaque(privateData)
        .takeRetainedValue()
      throw .codable("Failed to create JS object for \(Self.self)")
    case nil:
      _ = Unmanaged<JSClassAutoObjectStorage<ClassDefinition>>
        .fromOpaque(privateData)
        .takeRetainedValue()
      throw .codable("Host object creation is not supported by \(Engine.self)")
    }
  }
}
