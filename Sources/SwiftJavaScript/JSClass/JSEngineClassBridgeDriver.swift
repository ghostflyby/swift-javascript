public protocol JSEngineClassBridgeDriver: JSEngine where RuntimeHandle: Hashable {
  associatedtype ClassPropertyNameAccumulator

  static func makeClass(
    definition: JSEngineClassDefinition<
      Self,
      JSClassParentDescriptor<Self, ClassPropertyNameAccumulator>,
      ClassPropertyNameAccumulator
    >,
    in runtime: RuntimeHandle
  ) -> JSClass<Self>

  static func runtimeHandle(for context: ContextHandle) -> RuntimeHandle?

  static func makeClassObjectResultHandle(
    of jsClass: JSClass<Self>,
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
  public static func jsClass(in runtime: Engine.RuntimeHandle) -> JSClass<Engine> {
    let key = JSClassValueConvertibleRegistryKey(
      typeID: ObjectIdentifier(Self.self),
      runtime: AnyHashable(runtime)
    )
    let boxed = jsClassValueConvertibleRegistry.value(forKey: key) {
      JSClassValueConvertibleClassBox(
        Engine.makeClass(definition: Self.autoClassDefinition(), in: runtime)
      )
    }
    return boxed.value as! JSClass<Engine>
  }

  public static func tryDecode(
    _ value: borrowing JSValue<Engine>,
    in context: borrowing JSInstantContext<Engine>
  ) throws(JSValueConversionError) -> Self {
    guard value.isObject(in: context) else {
      throw .typeMismatch(expected: "object", actual: value.type(in: context))
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

  public static func tryEncode(
    _ value: Self,
    in context: borrowing JSInstantContext<Engine>
  ) throws(JSValueConversionError) -> JSValue<Engine> {
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
      return JSValue<Engine>(handleValue: object, in: context.driverContextHandle)
    case .exception:
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

  public static func tryDecode<E: JSValueConversionEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> Self {
    precondition(
      E.self == Engine.self,
      "This conversion path only supports \(Engine.self)"
    )
    let engineValue = JSValue<Engine>(
      handleValue: unsafeBitCast(value.retainHandle(), to: JSValueHandle<Engine>.self),
      in: unsafeBitCast(context.driverContextHandle, to: Engine.ContextHandle.self)
    )
    let engineContext = JSInstantContext<Engine>(
      handle: unsafeBitCast(context.driverContextHandle, to: Engine.ContextHandle.self)
    )
    return try Self.tryDecode(engineValue, in: engineContext)
  }

  public static func tryEncode<E: JSValueConversionEngine>(
    _ value: Self,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    precondition(
      E.self == Engine.self,
      "This conversion path only supports \(Engine.self)"
    )
    let engineContext = JSInstantContext<Engine>(
      handle: unsafeBitCast(context.driverContextHandle, to: Engine.ContextHandle.self)
    )
    let encoded = try Self.tryEncode(value, in: engineContext)
    let handle = unsafeBitCast(encoded.takeHandle(), to: JSValueHandle<E>.self)
    return JSValue<E>(handleValue: handle, in: context.driverContextHandle)
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

  public func toJSValue<E: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<E>
  ) -> JSValue<E> {
    Self.encode(self, in: context)
  }

  public func tryEncode<E: JSValueConversionEngine>(
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    try Self.tryEncode(self, in: context)
  }
}
