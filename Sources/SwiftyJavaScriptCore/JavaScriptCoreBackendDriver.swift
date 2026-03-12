import JavaScriptCore
import SwiftJavaScript

package final class JavaScriptCoreRawRuntime: @unchecked Sendable {
  package let ref: JSContextGroupRef

  package init(ref: JSContextGroupRef = JSContextGroupCreate()) {
    self.ref = ref
  }

  deinit {
    JSContextGroupRelease(ref)
  }
}

package final class JavaScriptCoreRawContext: @unchecked Sendable {
  package let runtime: JavaScriptCoreRawRuntime?
  package let ref: JSGlobalContextRef
  private let ownsContext: Bool

  package init(runtime: JavaScriptCoreRawRuntime) {
    self.runtime = runtime
    self.ref = JSGlobalContextCreateInGroup(runtime.ref, nil)
    self.ownsContext = true
  }

  package init(borrowing ref: JSGlobalContextRef) {
    self.runtime = nil
    self.ref = ref
    self.ownsContext = false
  }

  deinit {
    if ownsContext {
      JSGlobalContextRelease(ref)
    }
  }
}

package final class JavaScriptCoreRawValue: @unchecked Sendable {
  package let ref: JSValueRef
  package let context: JavaScriptCoreRawContext

  package init(ref: JSValueRef, context: JavaScriptCoreRawContext) {
    self.ref = ref
    self.context = context
    JSValueProtect(context.ref, ref)
  }

  deinit {
    JSValueUnprotect(context.ref, ref)
  }

  package var type: JSType {
    JSType(JSValueGetType(context.ref, ref))
  }

  package func toDouble() -> Double {
    JSValueToNumber(context.ref, ref, nil)
  }

  package func toString() -> String? {
    guard let stringRef = JSValueToStringCopy(context.ref, ref, nil) else {
      return nil
    }
    defer { JSStringRelease(stringRef) }
    return String(jsStringRef: stringRef)
  }
}

private let javaScriptCoreFunctionCallback: JSObjectCallAsFunctionCallback = {
  ctx, function, thisObject, argumentCount, arguments, exception in
  guard let ctx, let function, let thisObject else {
    return JSValueMakeUndefined(ctx)
  }

  let context = JSInstantContext(ctx: ctx)
  let callback = Unmanaged<Box<JSValue.JSFunctionCallback>>.fromOpaque(
    JSObjectGetPrivate(function)!
  ).takeUnretainedValue().value
  let functionValue = JSValue(ref: function, ctx: context)
  let thisValue = JSValue(ref: thisObject, ctx: context)
  let argumentsAddress = arguments.map { UInt(bitPattern: $0) } ?? 0
  let argumentsPointer = UnsafePointer<JSValueRef?>(bitPattern: argumentsAddress)
  let result = withJavaScriptCoreArguments(argumentsPointer, count: Int(argumentCount)) { args in
    callback(context, functionValue, thisValue, args).toPrivateResult()
  }

  switch result {
  case .value(let value):
    return value
  case .exception(let error):
    exception?.pointee = error
    return JSValueMakeUndefined(ctx)
  }
}

private func makeJavaScriptCoreFunctionClassDefinition() -> JavaScriptCore.JSClassDefinition {
  var definition = JavaScriptCore.kJSClassDefinitionEmpty
  definition.callAsFunction = javaScriptCoreFunctionCallback
  definition.finalize = { function in
    guard let function, let privateData = JSObjectGetPrivate(function) else {
      return
    }
    let callback = Unmanaged<Box<JSValue.JSFunctionCallback>>.fromOpaque(privateData)
      .takeRetainedValue()
    _ = callback.value
  }
  return definition
}

private func withJavaScriptCoreArguments<R: ~Copyable>(
  _ pointer: UnsafePointer<JSValueRef?>?,
  count: Int,
  _ body: (borrowing JSArguments) -> R
) -> R {
  var empty: JSValueRef? = nil
  return withUnsafePointer(to: &empty) { emptyPointer in
    let arguments = JSArguments(pointer: pointer ?? emptyPointer, count: count)
    return body(arguments)
  }
}

private enum JavaScriptCoreObjectLookup {
  case object(JSObjectRef)
  case exception(JavaScriptCoreRawValue)
}

package enum JavaScriptCoreBackendDriver: _JSEngineDriver {
  package typealias Engine = JavaScriptCoreEngine
  package typealias RawRuntime = JavaScriptCoreRawRuntime
  package typealias RawContext = JavaScriptCoreRawContext
  package typealias RawValue = JavaScriptCoreRawValue

  package static let capabilities = JSEngineCapabilities(
    supportsBigInt: true,
    supportsSymbol: true,
    supportsExternalArrayBuffer: true,
    supportsHostObjects: true,
    supportsESModules: false,
    supportsPromiseJobQueueControl: false
  )

  package static func makeRuntime() -> JavaScriptCoreRawRuntime {
    JavaScriptCoreRawRuntime()
  }

  package static func makeContext(in runtime: JavaScriptCoreRawRuntime)
    -> JavaScriptCoreRawContext
  {
    JavaScriptCoreRawContext(runtime: runtime)
  }

  package static func makeFunctionClass() -> JSClassRef {
    var definition = makeJavaScriptCoreFunctionClassDefinition()
    return JSClassCreate(&definition)!
  }

  package static func makeFunction(
    named name: String,
    callback: @escaping JSValue.JSFunctionCallback,
    in context: JavaScriptCoreRawContext,
    functionClass: JSClassRef
  ) -> JavaScriptCoreRawValue {
    let callbackRef = Unmanaged.passRetained(Box(callback)).toOpaque()
    guard let functionRef = JSObjectMake(context.ref, functionClass, callbackRef) else {
      let callback = Unmanaged<Box<JSValue.JSFunctionCallback>>.fromOpaque(callbackRef)
        .takeRetainedValue()
      _ = callback.value
      return makeUndefined(in: context)
    }
    if !name.isEmpty {
      _ = setProperty(
        "name",
        on: JavaScriptCoreRawValue(ref: functionRef, context: context),
        to: makeString(name, in: context),
        in: context,
        attributes: [.dontEnum, .readOnly]
      )
    }
    return JavaScriptCoreRawValue(ref: functionRef, context: context)
  }

  package static func evaluateScript(
    _ script: String,
    in context: JavaScriptCoreRawContext,
    sourceURL: String?,
    startingLineNumber: Int32
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    withJSString(script) { scriptRef in
      withOptionalJSString(sourceURL) { sourceURLRef in
        var exception: JSValueRef?
        let resultRef = JSEvaluateScript(
          context.ref,
          scriptRef,
          nil,
          sourceURLRef,
          startingLineNumber,
          &exception
        )

        if let exception {
          return .exception(JavaScriptCoreRawValue(ref: exception, context: context))
        }

        if let resultRef {
          return .value(JavaScriptCoreRawValue(ref: resultRef, context: context))
        }

        return .value(makeUndefined(in: context))
      }
    }
  }

  package static func makeString(
    _ value: String,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreRawValue {
    withJSString(value) { stringRef in
      JavaScriptCoreRawValue(ref: JSValueMakeString(context.ref, stringRef)!, context: context)
    }
  }

  package static func makeNumber(
    _ value: Double,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreRawValue {
    JavaScriptCoreRawValue(ref: JSValueMakeNumber(context.ref, value)!, context: context)
  }

  package static func makeBoolean(
    _ value: Bool,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreRawValue {
    JavaScriptCoreRawValue(ref: JSValueMakeBoolean(context.ref, value)!, context: context)
  }

  package static func makeNull(in context: JavaScriptCoreRawContext)
    -> JavaScriptCoreRawValue
  {
    JavaScriptCoreRawValue(ref: JSValueMakeNull(context.ref)!, context: context)
  }

  package static func makeUndefined(in context: JavaScriptCoreRawContext)
    -> JavaScriptCoreRawValue
  {
    JavaScriptCoreRawValue(ref: JSValueMakeUndefined(context.ref)!, context: context)
  }

  package static func makeObject(in context: JavaScriptCoreRawContext)
    -> JSDriverResult<JavaScriptCoreRawValue>
  {
    guard let objectRef = JSObjectMake(context.ref, nil, nil) else {
      return .exception(makeUndefined(in: context))
    }
    return .value(JavaScriptCoreRawValue(ref: objectRef, context: context))
  }

  package static func makeArray(in context: JavaScriptCoreRawContext)
    -> JSDriverResult<JavaScriptCoreRawValue>
  {
    var exception: JSValueRef?
    let objectRef = JSObjectMakeArray(context.ref, 0, nil, &exception)
    if let exception {
      return .exception(JavaScriptCoreRawValue(ref: exception, context: context))
    }
    if let objectRef {
      return .value(JavaScriptCoreRawValue(ref: objectRef, context: context))
    }
    return .value(makeUndefined(in: context))
  }

  package static func propertyNames(
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> [String] {
    switch objectRef(for: object, in: context) {
    case .exception:
      return []
    case .object(let objectRef):
      let names = JSObjectCopyPropertyNames(context.ref, objectRef)
      defer { JSPropertyNameArrayRelease(names) }

      let count = JSPropertyNameArrayGetCount(names)
      var result: [String] = []
      result.reserveCapacity(Int(count))
      for index in 0..<count {
        guard let keyRef = JSPropertyNameArrayGetNameAtIndex(names, index) else {
          continue
        }
        result.append(String(jsStringRef: keyRef))
      }
      return result
    }
  }

  package static func getProperty(
    _ key: String,
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    switch objectRef(for: object, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      return withJSString(key) { keyRef in
        var exception: JSValueRef?
        let valueRef = JSObjectGetProperty(context.ref, objectRef, keyRef, &exception)
        if let exception {
          return .exception(JavaScriptCoreRawValue(ref: exception, context: context))
        }
        if let valueRef {
          return .value(JavaScriptCoreRawValue(ref: valueRef, context: context))
        }
        return .value(makeUndefined(in: context))
      }
    }
  }

  package static func getProperty(
    _ key: JavaScriptCoreRawValue,
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    switch objectRef(for: object, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      var exception: JSValueRef?
      let valueRef = JSObjectGetPropertyForKey(context.ref, objectRef, key.ref, &exception)
      return result(value: valueRef, exception: exception, in: context)
    }
  }

  package static func getProperty(
    at index: UInt32,
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    switch objectRef(for: object, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      var exception: JSValueRef?
      let valueRef = JSObjectGetPropertyAtIndex(context.ref, objectRef, index, &exception)
      return result(value: valueRef, exception: exception, in: context)
    }
  }

  package static func hasProperty(
    _ key: String,
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> Bool {
    switch objectRef(for: object, in: context) {
    case .exception:
      return false
    case .object(let objectRef):
      return withJSString(key) { keyRef in
        JSObjectHasProperty(context.ref, objectRef, keyRef)
      }
    }
  }

  package static func hasProperty(
    _ key: JavaScriptCoreRawValue,
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> Bool {
    switch objectRef(for: object, in: context) {
    case .exception:
      return false
    case .object(let objectRef):
      var exception: JSValueRef?
      let result = JSObjectHasPropertyForKey(context.ref, objectRef, key.ref, &exception)
      return exception == nil && result
    }
  }

  package static func deleteProperty(
    _ key: String,
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<Void> {
    switch objectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      return withJSString(key) { keyRef in
        var exception: JSValueRef?
        JSObjectDeleteProperty(context.ref, objectRef, keyRef, &exception)
        if exception != nil {
          return .exception(())
        }
        return .value(())
      }
    }
  }

  package static func deleteProperty(
    _ key: JavaScriptCoreRawValue,
    on object: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<Void> {
    switch objectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      var exception: JSValueRef?
      JSObjectDeletePropertyForKey(context.ref, objectRef, key.ref, &exception)
      if exception != nil {
        return .exception(())
      }
      return .value(())
    }
  }

  package static func callFunction(
    _ function: JavaScriptCoreRawValue,
    this thisValue: JavaScriptCoreRawValue?,
    arguments: [JavaScriptCoreRawValue],
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    switch objectRef(for: function, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let functionRef):
      let thisObjectRef: JSObjectRef?
      if let thisValue {
        switch objectRef(for: thisValue, in: context) {
        case .exception(let exception):
          return .exception(exception)
        case .object(let objectRef):
          thisObjectRef = objectRef
        }
      } else {
        thisObjectRef = nil
      }

      var exception: JSValueRef?
      let refs = arguments.map { Optional($0.ref) }
      let resultRef = refs.withUnsafeBufferPointer { buffer in
        JSObjectCallAsFunction(
          context.ref,
          functionRef,
          thisObjectRef,
          buffer.count,
          buffer.baseAddress,
          &exception
        )
      }
      return result(value: resultRef, exception: exception, in: context)
    }
  }

  package static func construct(
    _ constructor: JavaScriptCoreRawValue,
    arguments: [JavaScriptCoreRawValue],
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    switch objectRef(for: constructor, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let constructorRef):
      var exception: JSValueRef?
      let refs = arguments.map { Optional($0.ref) }
      let resultRef = refs.withUnsafeBufferPointer { buffer in
        JSObjectCallAsConstructor(
          context.ref,
          constructorRef,
          buffer.count,
          buffer.baseAddress,
          &exception
        )
      }
      return result(value: resultRef, exception: exception, in: context)
    }
  }

  package static func toObject(
    _ value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    switch objectRef(for: value, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      return .value(JavaScriptCoreRawValue(ref: objectRef, context: context))
    }
  }

  package static func isArray(
    _ value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> Bool {
    JSValueIsArray(context.ref, value.ref)
  }

  package static func isDate(
    _ value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> Bool {
    JSValueIsDate(context.ref, value.ref)
  }

  package static func isInstanceOf(
    _ value: JavaScriptCoreRawValue,
    constructor: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> Bool {
    switch objectRef(for: constructor, in: context) {
    case .exception:
      return false
    case .object(let constructorRef):
      var exception: JSValueRef?
      let result = JSValueIsInstanceOfConstructor(
        context.ref, value.ref, constructorRef, &exception)
      return exception == nil && result
    }
  }

  package static func setProperty(
    _ key: String,
    on object: JavaScriptCoreRawValue,
    to value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext,
    attributes: JSHostMemberAttributes
  ) -> JSDriverResult<Void> {
    switch objectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      return withJSString(key) { keyRef in
        var exception: JSValueRef?
        JSObjectSetProperty(
          context.ref,
          objectRef,
          keyRef,
          value.ref,
          javaScriptCorePropertyAttributes(from: attributes),
          &exception
        )
        if exception != nil {
          return .exception(())
        }
        return .value(())
      }
    }
  }

  package static func setProperty(
    _ key: JavaScriptCoreRawValue,
    on object: JavaScriptCoreRawValue,
    to value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext,
    attributes: JSHostMemberAttributes
  ) -> JSDriverResult<Void> {
    switch objectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      var exception: JSValueRef?
      JSObjectSetPropertyForKey(
        context.ref,
        objectRef,
        key.ref,
        value.ref,
        javaScriptCorePropertyAttributes(from: attributes),
        &exception
      )
      if exception != nil {
        return .exception(())
      }
      return .value(())
    }
  }

  package static func setProperty(
    at index: UInt32,
    on object: JavaScriptCoreRawValue,
    to value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<Void> {
    switch objectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      var exception: JSValueRef?
      JSObjectSetPropertyAtIndex(context.ref, objectRef, index, value.ref, &exception)
      if exception != nil {
        return .exception(())
      }
      return .value(())
    }
  }

  private static func objectRef(
    for value: JavaScriptCoreRawValue,
    in context: JavaScriptCoreRawContext
  ) -> JavaScriptCoreObjectLookup {
    var exception: JSValueRef?
    guard let objectRef = JSValueToObject(context.ref, value.ref, &exception) else {
      if let exception {
        return .exception(JavaScriptCoreRawValue(ref: exception, context: context))
      }
      return .exception(makeUndefined(in: context))
    }
    return .object(objectRef)
  }

  private static func result(
    value resultRef: JSValueRef?,
    exception exceptionRef: JSValueRef?,
    in context: JavaScriptCoreRawContext
  ) -> JSDriverResult<JavaScriptCoreRawValue> {
    if let exceptionRef {
      return .exception(JavaScriptCoreRawValue(ref: exceptionRef, context: context))
    }
    if let resultRef {
      return .value(JavaScriptCoreRawValue(ref: resultRef, context: context))
    }
    return .value(makeUndefined(in: context))
  }
}

private func javaScriptCorePropertyAttributes(from attributes: JSHostMemberAttributes) -> UInt32 {
  var rawValue = UInt32(kJSPropertyAttributeNone)
  if attributes.contains(.readOnly) {
    rawValue |= UInt32(kJSPropertyAttributeReadOnly)
  }
  if attributes.contains(.dontEnum) {
    rawValue |= UInt32(kJSPropertyAttributeDontEnum)
  }
  if attributes.contains(.dontDelete) {
    rawValue |= UInt32(kJSPropertyAttributeDontDelete)
  }
  return rawValue
}

private func withJSString<R>(_ string: String, _ body: (JSStringRef) -> R) -> R {
  let ref = JSStringCreateWithCFString(string as CFString)!
  defer { JSStringRelease(ref) }
  return body(ref)
}

private func withOptionalJSString<R>(_ string: String?, _ body: (JSStringRef?) -> R) -> R {
  guard let string else {
    return body(nil)
  }
  return withJSString(string, body)
}
