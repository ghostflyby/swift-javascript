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
  package let runtime: JavaScriptCoreRawRuntime
  package let ref: JSGlobalContextRef

  package init(runtime: JavaScriptCoreRawRuntime) {
    self.runtime = runtime
    self.ref = JSGlobalContextCreateInGroup(runtime.ref, nil)
  }

  deinit {
    JSGlobalContextRelease(ref)
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
