import SwiftJavaScript
import Synchronization

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

public typealias QuickJSClassDefinition = JSEngineClassDefinition<
  QuickJSEngine,
  JSClassParentDescriptor<QuickJSEngine, Never>,
  Never
>

private final class QuickJSClassRecord: @unchecked Sendable {
  let definition: QuickJSClassDefinition
  let parentClass: JSClass<QuickJSEngine>?
  let exoticMethods: UnsafeMutablePointer<JSClassExoticMethods>

  init(definition: QuickJSClassDefinition, parentClass: JSClass<QuickJSEngine>?) {
    self.definition = definition
    self.parentClass = parentClass
    self.exoticMethods = .allocate(capacity: 1)
    self.exoticMethods.initialize(
      to: JSClassExoticMethods(
        get_own_property: nil,
        get_own_property_names: nil,
        delete_property: quickJSClassDeleteProperty,
        define_own_property: nil,
        has_property: quickJSClassHasProperty,
        get_property: quickJSClassGetProperty,
        set_property: quickJSClassSetProperty
      )
    )
  }

  deinit {
    exoticMethods.deinitialize(count: 1)
    exoticMethods.deallocate()
  }
}

private struct QuickJSClassRegistryKey: Hashable, Sendable {
  let runtime: QuickJSRuntimeHandle
  let classID: JSClassID
}

private struct QuickJSClassRegistry: Sendable, ~Copyable {
  private let records = Mutex<[QuickJSClassRegistryKey: QuickJSClassRecord]>([:])

  func record(_ record: QuickJSClassRecord, for key: QuickJSClassRegistryKey) {
    records.withLock {
      $0[key] = record
    }
  }

  func definition(for key: QuickJSClassRegistryKey) -> QuickJSClassDefinition? {
    records.withLock {
      $0[key]?.definition
    }
  }

  func record(for key: QuickJSClassRegistryKey) -> QuickJSClassRecord? {
    records.withLock {
      $0[key]
    }
  }

  func removeRecords(in runtime: QuickJSRuntimeHandle) {
    records.withLock {
      $0 = $0.filter { $0.key.runtime != runtime }
    }
  }
}

private let quickJSClassRegistry = QuickJSClassRegistry()

func removeQuickJSClassRecords(in runtime: QuickJSRuntimeHandle) {
  quickJSClassRegistry.removeRecords(in: runtime)
}

private struct QuickJSClassObjectContextRegistry: Sendable, ~Copyable {
  private let contexts = Mutex<[UInt: UInt]>([:])

  func record(_ contextRef: OpaquePointer, for privateData: UnsafeMutableRawPointer) {
    let key = UInt(bitPattern: privateData)
    let value = UInt(bitPattern: contextRef)
    contexts.withLock {
      $0[key] = value
    }
  }

  func removeContext(for privateData: UnsafeMutableRawPointer) -> OpaquePointer? {
    let key = UInt(bitPattern: privateData)
    return contexts.withLock {
      $0.removeValue(forKey: key).flatMap { OpaquePointer(bitPattern: $0) }
    }
  }
}

private let quickJSClassObjectContextRegistry = QuickJSClassObjectContextRegistry()

extension QuickJSEngine: JSEngineClassBridgeDriver {
  public typealias ClassPropertyNameAccumulator = Never

  public static func makeClass(
    definition: QuickJSClassDefinition,
    in runtime: QuickJSRuntimeHandle
  ) -> JSClass<QuickJSEngine> {
    var classID = JSClassID(0)
    JS_NewClassID(runtime.ref, &classID)

    let record = QuickJSClassRecord(
      definition: definition,
      parentClass: definition.parentClass?.jsClass(in: runtime)
    )
    quickJSClassRegistry.record(
      record,
      for: QuickJSClassRegistryKey(runtime: runtime, classID: classID)
    )
    return JSClass(
      adoptingHandleClass: QuickJSClassHandle(id: classID, runtime: runtime),
      retainedOwner: record
    )
  }

  public static func runtimeHandle(for context: QuickJSContextHandle) -> QuickJSRuntimeHandle? {
    QuickJSRuntimeHandle(ref: JS_GetRuntime(context.ref), ownsRuntime: false)
  }

  public static func makeClassObjectResultHandle(
    of jsClass: JSClass<QuickJSEngine>,
    privateData: UnsafeMutableRawPointer,
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    guard let definition = jsClassDefinition(jsClass, in: context) else {
      return nil
    }
    registerClassIfNeeded(jsClass, in: context)
    let object = JS_NewObjectClass(context.ref, jsClass.classHandle().id)
    if JS_IsException(object) {
      return quickJSResultHandle(for: object, in: context.ref)
    }
    if JS_SetOpaque(object, privateData) < 0 {
      JS_FreeValue(context.ref, object)
      let exception = JS_GetException(context.ref)
      return .exception(QuickJSValueHandle(ref: exception))
    }
    quickJSClassObjectContextRegistry.record(context.ref, for: privateData)
    initializeClassObject(object, definition: definition, in: context.ref)
    installStaticValueMembers(on: object, definition: definition, in: context.ref)
    installStaticFunctionMembers(on: object, definition: definition, in: context.ref)
    return .value(QuickJSValueHandle(ref: object))
  }

  public static func classObjectPrivateData(
    from value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> JSResult<UnsafeMutableRawPointer?>? {
    let classID = JS_GetClassID(value.ref)
    guard classID != JS_INVALID_CLASS_ID else {
      return .value(nil)
    }
    guard let runtime = runtimeHandle(for: context),
      quickJSClassRegistry.definition(
        for: QuickJSClassRegistryKey(runtime: runtime, classID: classID)
      ) != nil
    else {
      return .value(nil)
    }
    return .value(JS_GetOpaque2(context.ref, value.ref, classID))
  }

  public static func classDefinition(
    for classHandle: QuickJSClassHandle,
    in runtime: QuickJSRuntimeHandle
  ) -> QuickJSClassDefinition? {
    guard classHandle.runtime == nil || classHandle.runtime == runtime else {
      return nil
    }
    return quickJSClassRegistry.definition(
      for: QuickJSClassRegistryKey(runtime: runtime, classID: classHandle.id)
    )
  }
}

private func registerClassIfNeeded(
  _ jsClass: JSClass<QuickJSEngine>, in context: QuickJSContextHandle
) {
  let classID = jsClass.classHandle().id
  guard let runtimeHandle = QuickJSEngine.runtimeHandle(for: context),
    jsClass.classHandle().runtime == nil || jsClass.classHandle().runtime == runtimeHandle
  else {
    return
  }
  let runtime = runtimeHandle.ref
  guard !JS_IsRegisteredClass(runtime, classID) else {
    return
  }
  guard
    let record = quickJSClassRegistry.record(
      for: QuickJSClassRegistryKey(runtime: runtimeHandle, classID: classID)
    )
  else {
    return
  }

  let definition = record.definition
  if let parentClass = record.parentClass {
    registerClassIfNeeded(parentClass, in: context)
  }
  var classDefinition = JSClassDef()
  let className = definition.className ?? "SwiftHostObject"
  className.withCString { classNamePointer in
    classDefinition.class_name = classNamePointer
    classDefinition.finalizer = quickJSClassFinalizer
    classDefinition.gc_mark = nil
    classDefinition.call = nil
    classDefinition.exotic = record.exoticMethods
    _ = JS_NewClass(runtime, classID, &classDefinition)
  }

  let prototype = JS_NewObject(context.ref)
  if !JS_IsException(prototype) {
    if let parentClass = record.parentClass {
      let parentPrototype = JS_GetClassProto(context.ref, parentClass.classHandle().id)
      if !JS_IsException(parentPrototype) && JS_IsObject(parentPrototype) {
        _ = JS_SetPrototype(context.ref, prototype, parentPrototype)
      }
      JS_FreeValue(context.ref, parentPrototype)
    }
    JS_SetClassProto(context.ref, classID, prototype)
  }
}

private func jsClassDefinition(
  _ jsClass: JSClass<QuickJSEngine>,
  in context: QuickJSContextHandle
) -> QuickJSClassDefinition? {
  guard let runtime = QuickJSEngine.runtimeHandle(for: context) else {
    return nil
  }
  return QuickJSEngine.classDefinition(for: jsClass.classHandle(), in: runtime)
}

private func quickJSClassDefinition(
  for value: CQuickJSValue,
  in contextRef: OpaquePointer
) -> QuickJSClassDefinition? {
  let classID = JS_GetClassID(value)
  guard classID != JS_INVALID_CLASS_ID else {
    return nil
  }
  let runtime = QuickJSRuntimeHandle(ref: JS_GetRuntime(contextRef), ownsRuntime: false)
  return quickJSClassRegistry.definition(
    for: QuickJSClassRegistryKey(runtime: runtime, classID: classID)
  )
}

private func quickJSClassFinalizer(_ runtimeRef: OpaquePointer?, _ value: CQuickJSValue) {
  let classID = JS_GetClassID(value)
  guard let runtimeRef,
    classID != JS_INVALID_CLASS_ID,
    let definition = quickJSClassRegistry.definition(
      for: QuickJSClassRegistryKey(
        runtime: QuickJSRuntimeHandle(ref: runtimeRef, ownsRuntime: false),
        classID: classID
      )
    ),
    let privateData = JS_GetOpaque(value, classID)
  else {
    return
  }
  let contextRef = quickJSClassObjectContextRegistry.removeContext(for: privateData)
  if let finalize = definition.finalize, let contextRef {
    let thisValue = JSValue<QuickJSEngine>(
      handleValue: QuickJSValueHandle(ref: value), in: QuickJSContextHandle(ref: contextRef)
    )
    finalize(thisValue)
    _ = thisValue.takeHandle()
  }
  _ = Unmanaged<JSClassAutoObjectStorage<QuickJSClassDefinition>>
    .fromOpaque(privateData)
    .takeRetainedValue()
}

private func quickJSClassGetProperty(
  contextRef: OpaquePointer?,
  object: CQuickJSValue,
  atom: JSAtom,
  _: CQuickJSValue
) -> CQuickJSValue {
  guard let contextRef,
    let key = quickJSAtomString(atom, in: contextRef),
    let definition = quickJSClassDefinition(for: object, in: contextRef)
  else {
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }

  let contextHandle = QuickJSContextHandle(ref: contextRef)
  let context = JSInstantContext<QuickJSEngine>(handle: contextHandle)
  let thisValue = JSValue<QuickJSEngine>(
    handleValue: QuickJSValueHandle(ref: object),
    in: contextHandle
  )

  guard definition.getProperty != nil,
    definition.hasProperty == nil
      || definition.hasDynamicProperty(in: context, on: thisValue, forKey: key)
  else {
    thisValue.discard()
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }

  let result = definition.dynamicPropertyValue(in: context, on: thisValue, forKey: key)
  thisValue.discard()
  return quickJSClassCallbackReturnValue(result, in: contextRef)
}

private func quickJSClassSetProperty(
  contextRef: OpaquePointer?,
  object: CQuickJSValue,
  atom: JSAtom,
  value: CQuickJSValue,
  _: CQuickJSValue,
  flags: Int32
) -> Int32 {
  guard let contextRef,
    let key = quickJSAtomString(atom, in: contextRef),
    let definition = quickJSClassDefinition(for: object, in: contextRef)
  else {
    return 0
  }

  let contextHandle = QuickJSContextHandle(ref: contextRef)
  let context = JSInstantContext<QuickJSEngine>(handle: contextHandle)
  let thisValue = JSValue<QuickJSEngine>(
    handleValue: QuickJSValueHandle(ref: object), in: contextHandle
  )
  let newValue = JSValue<QuickJSEngine>(
    handleValue: QuickJSValueHandle(ref: value),
    in: contextHandle
  )

  let shouldUseDynamicSetter =
    definition.setProperty != nil
    && (definition.hasProperty == nil
      || definition.hasDynamicProperty(in: context, on: thisValue, forKey: key))
  if shouldUseDynamicSetter {
    guard
      let exception = definition.setDynamicPropertyException(
        in: context,
        on: thisValue,
        forKey: key,
        to: newValue
      )
    else {
      thisValue.discard()
      newValue.discard()
      return 1
    }
    thisValue.discard()
    newValue.discard()
    _ = JS_Throw(contextRef, exception.takeHandle().ref)
    return -1
  }

  thisValue.discard()
  newValue.discard()
  if flags & Int32(JS_PROP_NO_ADD) != 0 {
    return 0
  }
  return JS_DefinePropertyValue(
    contextRef,
    object,
    atom,
    JS_DupValue(contextRef, value),
    Int32(JS_PROP_CONFIGURABLE | JS_PROP_WRITABLE | JS_PROP_ENUMERABLE)
  )
}

private func quickJSClassHasProperty(
  contextRef: OpaquePointer?,
  object: CQuickJSValue,
  atom: JSAtom
) -> Int32 {
  guard let contextRef,
    let key = quickJSAtomString(atom, in: contextRef),
    let definition = quickJSClassDefinition(for: object, in: contextRef)
  else {
    return 0
  }

  let ownProperty = quickJSClassOwnPropertyExists(object, atom: atom, in: contextRef)
  if ownProperty != 0 {
    return ownProperty
  }

  let contextHandle = QuickJSContextHandle(ref: contextRef)
  let context = JSInstantContext<QuickJSEngine>(handle: contextHandle)
  let thisValue = JSValue<QuickJSEngine>(
    handleValue: QuickJSValueHandle(ref: object), in: contextHandle
  )

  let result: Int32 =
    definition.hasDynamicProperty(in: context, on: thisValue, forKey: key)
    ? 1 : 0
  thisValue.discard()
  return result
}

private func quickJSClassOwnPropertyExists(
  _ object: CQuickJSValue,
  atom: JSAtom,
  in contextRef: OpaquePointer
) -> Int32 {
  var descriptor = JSPropertyDescriptor()
  let result = JS_GetOwnProperty(contextRef, &descriptor, object, atom)
  guard result == 1 else {
    return result
  }
  JS_FreeValue(contextRef, descriptor.value)
  JS_FreeValue(contextRef, descriptor.getter)
  JS_FreeValue(contextRef, descriptor.setter)
  return 1
}

private func quickJSClassDeleteProperty(
  contextRef: OpaquePointer?,
  object: CQuickJSValue,
  atom: JSAtom
) -> Int32 {
  guard let contextRef,
    let key = quickJSAtomString(atom, in: contextRef),
    let definition = quickJSClassDefinition(for: object, in: contextRef)
  else {
    return 0
  }

  let contextHandle = QuickJSContextHandle(ref: contextRef)
  let context = JSInstantContext<QuickJSEngine>(handle: contextHandle)
  let thisValue = JSValue<QuickJSEngine>(
    handleValue: QuickJSValueHandle(ref: object),
    in: contextHandle
  )

  let result: Int32
  if definition.deleteProperty != nil,
    definition.hasProperty == nil
      || definition.hasDynamicProperty(in: context, on: thisValue, forKey: key)
  {
    result = definition.deleteDynamicProperty(in: context, on: thisValue, forKey: key) ? 1 : 0
  } else {
    result = 1
  }
  thisValue.discard()
  return result
}

private func initializeClassObject(
  _ object: CQuickJSValue,
  definition: QuickJSClassDefinition,
  in contextRef: OpaquePointer
) {
  guard let initialize = definition.initialize else {
    return
  }
  let contextHandle = QuickJSContextHandle(ref: contextRef)
  let context = JSInstantContext<QuickJSEngine>(handle: contextHandle)
  let thisValue = JSValue<QuickJSEngine>(
    handleValue: QuickJSValueHandle(ref: object),
    in: contextHandle
  )
  initialize(thisValue, context)
  thisValue.discard()
}

private func installStaticValueMembers(
  on object: CQuickJSValue,
  definition: QuickJSClassDefinition,
  in contextRef: OpaquePointer
) {
  for value in definition.staticValues {
    let atom = JS_NewAtom(contextRef, value.name)
    guard atom != JS_ATOM_NULL else {
      continue
    }
    defer { JS_FreeAtom(contextRef, atom) }
    let getter = quickJSStaticValueGetter(value, in: contextRef)
    let setter =
      value.attributes.contains(.readOnly)
      ? quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
      : quickJSStaticValueSetter(value, in: contextRef)
    _ = JS_DefinePropertyGetSet(
      contextRef,
      object,
      atom,
      getter,
      setter,
      quickJSAccessorPropertyFlags(for: value.attributes)
    )
  }
}

private func installStaticFunctionMembers(
  on object: CQuickJSValue,
  definition: QuickJSClassDefinition,
  in contextRef: OpaquePointer
) {
  for function in definition.staticFunctions {
    let functionValue = quickJSStaticFunctionValue(function, in: contextRef)
    if JS_IsException(functionValue) {
      continue
    }
    _ = function.name.withCString {
      JS_DefinePropertyValueStr(
        contextRef,
        object,
        $0,
        functionValue,
        quickJSPropertyFlags(for: function.attributes)
      )
    }
  }
}

private final class QuickJSStaticValueBox: @unchecked Sendable {
  let value: JSStaticValue<QuickJSEngine>

  init(_ value: JSStaticValue<QuickJSEngine>) {
    self.value = value
  }
}

private func quickJSStaticValueGetter(
  _ value: JSStaticValue<QuickJSEngine>,
  in contextRef: OpaquePointer
) -> CQuickJSValue {
  let box = Unmanaged.passRetained(QuickJSStaticValueBox(value))
  let function = "\(value.name).get".withCString {
    JS_NewCClosure(
      contextRef,
      quickJSStaticValueGetterCallback,
      $0,
      quickJSStaticValueFinalizer,
      0,
      0,
      box.toOpaque()
    )
  }
  if JS_IsException(function) {
    _ = box.takeRetainedValue()
  }
  return function
}

private func quickJSStaticValueSetter(
  _ value: JSStaticValue<QuickJSEngine>,
  in contextRef: OpaquePointer
) -> CQuickJSValue {
  let box = Unmanaged.passRetained(QuickJSStaticValueBox(value))
  let function = "\(value.name).set".withCString {
    JS_NewCClosure(
      contextRef,
      quickJSStaticValueSetterCallback,
      $0,
      quickJSStaticValueFinalizer,
      0,
      0,
      box.toOpaque()
    )
  }
  if JS_IsException(function) {
    _ = box.takeRetainedValue()
  }
  return function
}

private func quickJSStaticValueGetterCallback(
  contextRef: OpaquePointer?,
  thisValueRef: CQuickJSValue,
  _: Int32,
  _: UnsafeMutablePointer<CQuickJSValue>?,
  _: Int32,
  opaque: UnsafeMutableRawPointer?
) -> CQuickJSValue {
  guard let contextRef, let opaque else {
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }
  let contextHandle = QuickJSContextHandle(ref: contextRef)
  let context = JSInstantContext<QuickJSEngine>(handle: contextHandle)
  let value = Unmanaged<QuickJSStaticValueBox>
    .fromOpaque(opaque)
    .takeUnretainedValue()
    .value
  let thisValue = JSValue<QuickJSEngine>(
    handleValue: QuickJSValueHandle(ref: thisValueRef),
    in: contextHandle
  )
  let result = value.propertyValue(in: context, on: thisValue)
  thisValue.discard()
  return quickJSClassCallbackReturnValue(result, in: contextRef)
}

private func quickJSStaticValueSetterCallback(
  contextRef: OpaquePointer?,
  thisValueRef: CQuickJSValue,
  argumentCount: Int32,
  arguments: UnsafeMutablePointer<CQuickJSValue>?,
  _: Int32,
  opaque: UnsafeMutableRawPointer?
) -> CQuickJSValue {
  guard let contextRef, let opaque else {
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }
  let contextHandle = QuickJSContextHandle(ref: contextRef)
  let context = JSInstantContext<QuickJSEngine>(handle: contextHandle)
  let value = Unmanaged<QuickJSStaticValueBox>
    .fromOpaque(opaque)
    .takeUnretainedValue()
    .value
  let thisValue = JSValue<QuickJSEngine>(
    handleValue: QuickJSValueHandle(ref: thisValueRef),
    in: contextHandle
  )
  let newValue = JSValue<QuickJSEngine>(
    handleValue: QuickJSValueHandle(
      ref: argumentCount > 0 && arguments != nil
        ? arguments![0] : quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED)),
    ),
    in: contextHandle
  )
  let exception = value.setPropertyException(in: context, on: thisValue, to: newValue)
  thisValue.discard()
  newValue.discard()
  guard let exception else {
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }
  return JS_Throw(contextRef, exception.takeHandle().ref)
}

private func quickJSStaticValueFinalizer(_ opaque: UnsafeMutableRawPointer?) {
  guard let opaque else {
    return
  }
  _ = Unmanaged<QuickJSStaticValueBox>.fromOpaque(opaque).takeRetainedValue()
}

private final class QuickJSStaticFunctionBox: @unchecked Sendable {
  let function: JSStaticFunction<QuickJSEngine>

  init(_ function: JSStaticFunction<QuickJSEngine>) {
    self.function = function
  }
}

private func quickJSStaticFunctionValue(
  _ function: JSStaticFunction<QuickJSEngine>,
  in contextRef: OpaquePointer
) -> CQuickJSValue {
  let box = Unmanaged.passRetained(QuickJSStaticFunctionBox(function))
  let functionValue = function.name.withCString {
    JS_NewCClosure(
      contextRef,
      quickJSStaticFunctionCallback,
      $0,
      quickJSStaticFunctionFinalizer,
      0,
      0,
      box.toOpaque()
    )
  }
  if JS_IsException(functionValue) {
    _ = box.takeRetainedValue()
  }
  return functionValue
}

private func quickJSStaticFunctionCallback(
  contextRef: OpaquePointer?,
  thisValueRef: CQuickJSValue,
  argumentCount: Int32,
  arguments: UnsafeMutablePointer<CQuickJSValue>?,
  _: Int32,
  opaque: UnsafeMutableRawPointer?
) -> CQuickJSValue {
  guard let contextRef, let opaque else {
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }

  let contextHandle = QuickJSContextHandle(ref: contextRef)
  let context = JSInstantContext<QuickJSEngine>(handle: contextHandle)
  let function = Unmanaged<QuickJSStaticFunctionBox>
    .fromOpaque(opaque)
    .takeUnretainedValue()
    .function
  let thisValue = JSValue<QuickJSEngine>(
    handleValue: QuickJSValueHandle(ref: thisValueRef),
    in: contextHandle
  )

  let result = quickJSClassArguments(arguments, count: Int(argumentCount), contextRef: contextRef) {
    function.callResult(in: context, on: thisValue, with: $0)
  }
  thisValue.discard()
  return quickJSClassCallbackReturnValue(result, in: contextRef)
}

private func quickJSStaticFunctionFinalizer(_ opaque: UnsafeMutableRawPointer?) {
  guard let opaque else {
    return
  }
  _ = Unmanaged<QuickJSStaticFunctionBox>.fromOpaque(opaque).takeRetainedValue()
}

private func quickJSClassArguments<R: ~Copyable>(
  _ arguments: UnsafeMutablePointer<CQuickJSValue>?,
  count: Int,
  contextRef: OpaquePointer,
  _ body: (borrowing JSArguments<QuickJSEngine>) -> R
) -> R {
  let swiftArguments = JSArguments<QuickJSEngine>(
    count: count,
    borrowedValueHandleAt: { index, contextHandle in
      guard index >= 0, index < count, let arguments else {
        return nil
      }
      return QuickJSValueHandle(ref: arguments[index])
    }
  )
  return body(swiftArguments)
}

private func quickJSClassCallbackReturnValue(
  _ result: consuming JSResult<SwiftJavaScript.JSValue<QuickJSEngine>>,
  in contextRef: OpaquePointer
) -> CQuickJSValue {
  switch consume result {
  case .value(let value):
    return value.takeHandle().ref
  case .exception(let error):
    return JS_Throw(contextRef, error.takeHandle().ref)
  }
}

private func quickJSAtomString(_ atom: JSAtom, in contextRef: OpaquePointer) -> String? {
  var length = 0
  guard let cString = JS_AtomToCStringLen(contextRef, &length, atom) else {
    return nil
  }
  defer { JS_FreeCString(contextRef, cString) }
  let bytes = UnsafeRawPointer(cString).assumingMemoryBound(to: UInt8.self)
  return String(decoding: UnsafeBufferPointer(start: bytes, count: length), as: UTF8.self)
}

private func quickJSPropertyFlags(for attributes: JSPropertyAttributes) -> Int32 {
  var flags = Int32(JS_PROP_HAS_VALUE | JS_PROP_HAS_CONFIGURABLE | JS_PROP_HAS_WRITABLE)
  if !attributes.contains(.dontDelete) {
    flags |= Int32(JS_PROP_CONFIGURABLE)
  }
  if !attributes.contains(.readOnly) {
    flags |= Int32(JS_PROP_WRITABLE)
  }
  if !attributes.contains(.dontEnum) {
    flags |= Int32(JS_PROP_ENUMERABLE)
  }
  return flags
}

private func quickJSAccessorPropertyFlags(for attributes: JSPropertyAttributes) -> Int32 {
  var flags = Int32(0)
  if !attributes.contains(.dontDelete) {
    flags |= Int32(JS_PROP_CONFIGURABLE)
  }
  if !attributes.contains(.dontEnum) {
    flags |= Int32(JS_PROP_ENUMERABLE)
  }
  return flags
}
