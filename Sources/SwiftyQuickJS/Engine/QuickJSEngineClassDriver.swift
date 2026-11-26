import SwiftJavaScript
import Synchronization

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

public typealias QJSClassDefinition = JSEngineClassDefinition<
  QJSEngine,
  JSClassParentDescriptor<QJSEngine, Never>,
  Never
>

private final class QuickJSClassRecord: @unchecked Sendable {
  let definition: QJSClassDefinition
  let parentClass: QJSClass?
  let exoticMethods: UnsafeMutablePointer<JSClassExoticMethods>

  init(definition: QJSClassDefinition, parentClass: QJSClass?) {
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
  let runtime: UInt
  let classID: JSClassID
}

private struct QuickJSClassRegistry: Sendable, ~Copyable {
  private let records = Mutex<[QuickJSClassRegistryKey: QuickJSClassRecord]>([:])

  func record(_ record: QuickJSClassRecord, for key: QuickJSClassRegistryKey) {
    records.withLock {
      $0[key] = record
    }
  }

  func definition(for key: QuickJSClassRegistryKey) -> QJSClassDefinition? {
    records.withLock {
      $0[key]?.definition
    }
  }

  func record(for key: QuickJSClassRegistryKey) -> QuickJSClassRecord? {
    records.withLock {
      $0[key]
    }
  }

  func removeRecords(in runtime: OpaquePointer) {
    let runtimeBits = UInt(bitPattern: runtime)
    records.withLock {
      $0 = $0.filter { $0.key.runtime != runtimeBits }
    }
  }
}

private let quickJSClassRegistry = QuickJSClassRegistry()

/// Class cache keyed by Swift type identity plus runtime. The key deliberately
/// does not contain the class ID: the ID is allocated while the class is
/// being created, so keying on it would never hit. Reuse is per runtime —
/// one Swift type maps to one `QJSClass` there — while the record table keeps
/// its `(runtime, classID)` key.
private struct QuickJSClassCacheKey: Hashable, Sendable {
  let identity: ObjectIdentifier
  let runtime: UInt
}

private let quickJSClassCache = SwiftJavaScript.JSClassMapRegistry<
  QuickJSClassCacheKey, QJSClass
>()

func removeQuickJSClassRecords(in runtime: OpaquePointer) {
  quickJSClassRegistry.removeRecords(in: runtime)
  let runtimeBits = UInt(bitPattern: runtime)
  quickJSClassCache.removeValues { $0.runtime == runtimeBits }
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

extension QJSEngine: JSEngineClassBridgeDriver {
  public typealias Value = QJSValue
  public typealias InstantContext = QJSInstantContext
  public typealias Arguments = QJSArguments
  public typealias Class = QJSClass
  public typealias ClassPropertyNameAccumulator = Never

  public static func makeClass(
    definition: QJSClassDefinition,
    identity: ObjectIdentifier,
    in context: borrowing QJSInstantContext
  ) -> QJSClass {
    let runtime = QJSEngine.runtimeRef(for: context.contextRef)
    let key = QuickJSClassCacheKey(identity: identity, runtime: UInt(bitPattern: runtime))
    return quickJSClassCache.value(forKey: key) {
      // Only the ID and the record are created here. Registering the engine
      // class (`JS_NewClass`/`JS_SetClassProto`) stays in `makeHostObject`'s
      // `registerClassIfNeeded`: doing it here would make that function's
      // `JS_IsRegisteredClass` early return skip the prototype and the parent
      // prototype wiring.
      var classID = JSClassID(0)
      JS_NewClassID(runtime, &classID)

      let record = QuickJSClassRecord(
        definition: definition,
        parentClass: definition.parentClass?.jsClass(in: context)
      )
      quickJSClassRegistry.record(
        record,
        for: QuickJSClassRegistryKey(runtime: UInt(bitPattern: runtime), classID: classID)
      )
      return QJSClass(
        classID: classID,
        runtimeRef: runtime,
        retainedOwner: record
      )
    }
  }

  public static func makeHostObject(
    of jsClass: QJSClass,
    privateData: UnsafeMutableRawPointer,
    in context: borrowing QJSInstantContext
  ) -> QJSValue? {
    let contextRef = context.contextRef
    guard let definition = jsClassDefinition(jsClass, in: contextRef) else {
      return nil
    }
    registerClassIfNeeded(jsClass, in: contextRef)
    let object = JS_NewObjectClass(contextRef, jsClass.classID)
    if JS_IsException(object) {
      // The failure path's references belong to the engine: clear the pending
      // exception and settle both values here, then report "no object".
      JS_FreeValue(contextRef, object)
      let exception = JS_GetException(contextRef)
      JS_FreeValue(contextRef, exception)
      return nil
    }
    if JS_SetOpaque(object, privateData) < 0 {
      JS_FreeValue(contextRef, object)
      let exception = JS_GetException(contextRef)
      JS_FreeValue(contextRef, exception)
      return nil
    }
    quickJSClassObjectContextRegistry.record(contextRef, for: privateData)
    initializeClassObject(object, definition: definition, in: contextRef)
    installStaticValueMembers(on: object, definition: definition, in: contextRef)
    installStaticFunctionMembers(on: object, definition: definition, in: contextRef)
    return context.adoptCreated(object)
  }

  public static func hostObjectPrivateData(
    of value: borrowing QJSValue,
    in context: borrowing QJSInstantContext
  ) -> UnsafeMutableRawPointer? {
    let contextRef = context.contextRef
    let classID = JS_GetClassID(value.value)
    guard classID != JS_INVALID_CLASS_ID else {
      return nil
    }
    let runtime = QJSEngine.runtimeRef(for: contextRef)
    guard
      quickJSClassRegistry.definition(
        for: QuickJSClassRegistryKey(runtime: UInt(bitPattern: runtime), classID: classID)
      ) != nil
    else {
      return nil
    }
    return JS_GetOpaque2(contextRef, value.value, classID)
  }

  package static func classDefinition(
    for classID: JSClassID,
    runtimeRef: OpaquePointer?,
    in runtime: OpaquePointer
  ) -> QJSClassDefinition? {
    guard runtimeRef == nil || runtimeRef == runtime else {
      return nil
    }
    return quickJSClassRegistry.definition(
      for: QuickJSClassRegistryKey(runtime: UInt(bitPattern: runtime), classID: classID)
    )
  }
}

private func registerClassIfNeeded(
  _ jsClass: QJSClass, in context: OpaquePointer
) {
  let classID = jsClass.classID
  let runtimeHandle = QJSEngine.runtimeRef(for: context)
  guard jsClass.runtimeRef == nil || jsClass.runtimeRef == runtimeHandle else {
    return
  }
  let runtime = runtimeHandle
  guard !JS_IsRegisteredClass(runtime, classID) else {
    return
  }
  guard
    let record = quickJSClassRegistry.record(
      for: QuickJSClassRegistryKey(runtime: UInt(bitPattern: runtimeHandle), classID: classID)
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

  let prototype = JS_NewObject(context)
  if !JS_IsException(prototype) {
    if let parentClass = record.parentClass {
      let parentPrototype = JS_GetClassProto(context, parentClass.classID)
      if !JS_IsException(parentPrototype) && JS_IsObject(parentPrototype) {
        _ = JS_SetPrototype(context, prototype, parentPrototype)
      }
      JS_FreeValue(context, parentPrototype)
    }
    JS_SetClassProto(context, classID, prototype)
  }
}

private func jsClassDefinition(
  _ jsClass: QJSClass,
  in context: OpaquePointer
) -> QJSClassDefinition? {
  let runtime = QJSEngine.runtimeRef(for: context)
  return QJSEngine.classDefinition(
    for: jsClass.classID,
    runtimeRef: jsClass.runtimeRef,
    in: runtime
  )
}

private func quickJSClassDefinition(
  for value: CQuickJSValue,
  in contextRef: OpaquePointer
) -> QJSClassDefinition? {
  let classID = JS_GetClassID(value)
  guard classID != JS_INVALID_CLASS_ID else {
    return nil
  }
  let runtime = QJSEngine.runtimeRef(for: contextRef)
  return quickJSClassRegistry.definition(
    for: QuickJSClassRegistryKey(runtime: UInt(bitPattern: runtime), classID: classID)
  )
}

private func quickJSClassFinalizer(_ runtimeRef: OpaquePointer?, _ value: CQuickJSValue) {
  let classID = JS_GetClassID(value)
  guard let runtimeRef,
    classID != JS_INVALID_CLASS_ID,
    let definition = quickJSClassRegistry.definition(
      for: QuickJSClassRegistryKey(
        runtime: UInt(bitPattern: runtimeRef),
        classID: classID
      )
    ),
    let privateData = JS_GetOpaque(value, classID)
  else {
    return
  }
  let contextRef = quickJSClassObjectContextRegistry.removeContext(for: privateData)
  if let finalize = definition.finalize, let contextRef {
    let thisValue = QJSValue(
      value: value,
      contextRef: contextRef
    )
    finalize(thisValue)
  }
  _ = Unmanaged<JSClassAutoObjectStorage<QJSClassDefinition>>
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

  let context = QJSInstantContext(contextRef: contextRef)
  let thisValue = QJSValue(
    value: object,
    contextRef: contextRef
  )

  guard definition.getProperty != nil,
    definition.hasProperty == nil
      || definition.hasDynamicProperty(in: context, on: thisValue, forKey: key)
  else {
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }

  let result = definition.dynamicPropertyValue(in: context, on: thisValue, forKey: key)
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

  let context = QJSInstantContext(contextRef: contextRef)
  let thisValue = QJSValue(value: object, contextRef: contextRef)
  let newValue = QJSValue(
    value: value,
    contextRef: contextRef
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
      return 1
    }
    _ = JS_Throw(contextRef, JS_DupValue(contextRef, exception.value))
    return -1
  }

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

  let context = QJSInstantContext(contextRef: contextRef)
  let thisValue = QJSValue(value: object, contextRef: contextRef)

  let result: Int32 =
    definition.hasDynamicProperty(in: context, on: thisValue, forKey: key)
    ? 1 : 0
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

  let context = QJSInstantContext(contextRef: contextRef)
  let thisValue = QJSValue(
    value: object,
    contextRef: contextRef
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
  return result
}

private func initializeClassObject(
  _ object: CQuickJSValue,
  definition: QJSClassDefinition,
  in contextRef: OpaquePointer
) {
  guard let initialize = definition.initialize else {
    return
  }
  let context = QJSInstantContext(contextRef: contextRef)
  let thisValue = QJSValue(
    value: object,
    contextRef: contextRef
  )
  initialize(thisValue, context)
}

private func installStaticValueMembers(
  on object: CQuickJSValue,
  definition: QJSClassDefinition,
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
  definition: QJSClassDefinition,
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
  let value: JSStaticValue<QJSEngine>

  init(_ value: JSStaticValue<QJSEngine>) {
    self.value = value
  }
}

private func quickJSStaticValueGetter(
  _ value: JSStaticValue<QJSEngine>,
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
  _ value: JSStaticValue<QJSEngine>,
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
  let context = QJSInstantContext(contextRef: contextRef)
  let value = Unmanaged<QuickJSStaticValueBox>
    .fromOpaque(opaque)
    .takeUnretainedValue()
    .value
  let thisValue = QJSValue(
    value: thisValueRef,
    contextRef: contextRef
  )
  let result = value.propertyValue(in: context, on: thisValue)
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
  let context = QJSInstantContext(contextRef: contextRef)
  let value = Unmanaged<QuickJSStaticValueBox>
    .fromOpaque(opaque)
    .takeUnretainedValue()
    .value
  let thisValue = QJSValue(
    value: thisValueRef,
    contextRef: contextRef
  )
  let newValue = QJSValue(
    value: argumentCount > 0 && arguments != nil
      ? arguments![0] : quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED)),
    contextRef: contextRef
  )
  let exception = value.setPropertyException(in: context, on: thisValue, to: newValue)
  guard let exception else {
    return quickJSImmediateValue(tag: Int32(JS_TAG_UNDEFINED))
  }
  return JS_Throw(contextRef, JS_DupValue(contextRef, exception.value))
}

private func quickJSStaticValueFinalizer(_ opaque: UnsafeMutableRawPointer?) {
  guard let opaque else {
    return
  }
  _ = Unmanaged<QuickJSStaticValueBox>.fromOpaque(opaque).takeRetainedValue()
}

private final class QuickJSStaticFunctionBox: @unchecked Sendable {
  let function: JSStaticFunction<QJSEngine>

  init(_ function: JSStaticFunction<QJSEngine>) {
    self.function = function
  }
}

private func quickJSStaticFunctionValue(
  _ function: JSStaticFunction<QJSEngine>,
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

  let context = QJSInstantContext(contextRef: contextRef)
  let function = Unmanaged<QuickJSStaticFunctionBox>
    .fromOpaque(opaque)
    .takeUnretainedValue()
    .function
  let thisValue = QJSValue(
    value: thisValueRef,
    contextRef: contextRef
  )

  let result = quickJSClassArguments(arguments, count: Int(argumentCount), contextRef: contextRef) {
    function.callResult(in: context, on: thisValue, with: $0)
  }
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
  _ body: (borrowing QJSArguments) -> R
) -> R {
  let swiftArguments = QJSArguments(
    count: count,
    borrowedValueAt: { index, _ in
      guard index >= 0, index < count, let arguments else {
        return nil
      }
      return arguments[index]
    }
  )
  return body(swiftArguments)
}

private func quickJSClassCallbackReturnValue(
  _ result: consuming JSResult<QJSValue>,
  in contextRef: OpaquePointer
) -> CQuickJSValue {
  // QuickJS takes ownership of callback return values and of values passed
  // to JS_Throw. The `QJSValue` is a non-owning local view whose backing
  // reference stays with its arena, so hand the engine a duplicate.
  switch consume result {
  case .value(let value):
    return JS_DupValue(contextRef, value.value)
  case .exception(let error):
    return JS_Throw(contextRef, JS_DupValue(contextRef, error.value))
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
