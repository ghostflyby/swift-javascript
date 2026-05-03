import Foundation
import JavaScriptCore
import SwiftJavaScript

enum JavaScriptCoreObjectLookup {
  case object(JSObjectRef)
  case exception(JavaScriptCoreValueHandle)
}

public enum JavaScriptCoreEngine: Sendable, SendableMetatype {
  public typealias ValueHandle = JavaScriptCoreValueHandle
  public typealias ClassHandle = JavaScriptCoreClassHandle
  public typealias Engine = JavaScriptCoreEngine
  public typealias RuntimeHandle = JavaScriptCoreRuntimeHandle
  public typealias ContextHandle = JavaScriptCoreContextHandle
  public typealias PropertyStringKeyHandle = JavaScriptCorePropertyStringKeyHandle
  public typealias PreparedScriptHandle = JavaScriptCorePreparedScriptHandle
}

func javaScriptCoreObjectRef(
  for value: JavaScriptCoreValueHandle,
  in context: JavaScriptCoreContextHandle
) -> JavaScriptCoreObjectLookup {
  var exception: JSValueRef?
  guard let objectRef = JSValueToObject(context.ref, value.ref, &exception) else {
    if let exception {
      return .exception(JavaScriptCoreValueHandle(ref: exception, contextRef: context.ref))
    }
    return .exception(javaScriptCoreMakeUndefined(in: context))
  }
  return .object(objectRef)
}

func javaScriptCoreResult(
  value resultRef: JSValueRef?,
  exception exceptionRef: JSValueRef?,
  in context: JavaScriptCoreContextHandle
) -> JSResult<JavaScriptCoreValueHandle> {
  if let exceptionRef {
    return .exception(JavaScriptCoreValueHandle(ref: exceptionRef, contextRef: context.ref))
  }
  if let resultRef {
    return .value(JavaScriptCoreValueHandle(ref: resultRef, contextRef: context.ref))
  }
  return .value(javaScriptCoreMakeUndefined(in: context))
}

func javaScriptCoreMakeUndefined(in context: JavaScriptCoreContextHandle)
  -> JavaScriptCoreValueHandle
{
  JavaScriptCoreValueHandle(ref: JSValueMakeUndefined(context.ref)!, contextRef: context.ref)
}

func javaScriptCoreMakeStringValue(
  _ value: String,
  in context: JavaScriptCoreContextHandle
) -> JavaScriptCoreValueHandle {
  withJavaScriptCoreString(value) { stringHandle in
    JavaScriptCoreValueHandle(
      ref: JSValueMakeString(context.ref, stringHandle)!,
      contextRef: context.ref
    )
  }
}

func javaScriptCoreString(_ value: JSValueRef, in context: JSContextRef) -> String? {
  guard let stringHandle = JSValueToStringCopy(context, value, nil) else {
    return nil
  }
  defer { JSStringRelease(stringHandle) }
  return javaScriptCoreString(stringHandle)
}

func javaScriptCoreString(_ string: JSStringRef) -> String {
  let length = JSStringGetLength(string)
  let characters = JSStringGetCharactersPtr(string)!
  return String(decoding: UnsafeBufferPointer(start: characters, count: length), as: UTF16.self)
}

func withJavaScriptCoreString<R>(_ string: String, _ body: (JSStringRef) -> R) -> R {
  let stringHandle = JSStringCreateWithCFString(string as CFString)!
  defer { JSStringRelease(stringHandle) }
  return body(stringHandle)
}

func withJavaScriptCoreString<R>(_ string: StaticString, _ body: (JSStringRef) -> R) -> R {
  let stringHandle =
    if string.hasPointerRepresentation {
      JSStringCreateWithUTF8CString(
        UnsafeRawPointer(string.utf8Start).assumingMemoryBound(to: CChar.self)
      )!
    } else {
      JSStringCreateWithCFString(String(describing: string) as CFString)!
    }
  defer { JSStringRelease(stringHandle) }
  return body(stringHandle)
}

func withOptionalJavaScriptCoreString<R>(_ string: String?, _ body: (JSStringRef?) -> R) -> R {
  guard let string else {
    return body(nil)
  }
  return withJavaScriptCoreString(string, body)
}
