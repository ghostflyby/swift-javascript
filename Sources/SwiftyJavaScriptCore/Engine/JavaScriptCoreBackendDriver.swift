import Foundation
import JavaScriptCore
import SwiftJavaScript

enum JavaScriptCoreObjectLookup {
  case object(JSObjectRef)
  case exception(JSCValueHandle)
}

public enum JSCEngine: Sendable {
  public typealias ValueHandle = JSCValueHandle
  public typealias OwnedValueHandle = JSCOwnedValueHandle
  public typealias ClassHandle = JSCClassHandle
  public typealias Engine = JSCEngine
  public typealias RuntimeHandle = JSCRuntimeHandle
  public typealias ContextHandle = JSCContextHandle
  public typealias PropertyStringKeyHandle = JSCPropertyStringKeyHandle
  public typealias PreparedScriptHandle = JSCPreparedScriptHandle
}

private struct JavaScriptCoreSharedStringRef: @unchecked Sendable {
  let ref: JSStringRef
}

private let javaScriptCoreEmptyString = JavaScriptCoreSharedStringRef(
  ref: JSStringCreateWithUTF8CString("")!
)

private var javaScriptCoreEmptyStringRef: JSStringRef {
  javaScriptCoreEmptyString.ref
}

func javaScriptCoreObjectRef(
  for value: JSCValueHandle,
  in context: JSCContextHandle
) -> JavaScriptCoreObjectLookup {
  var exception: JSValueRef?
  guard let objectRef = JSValueToObject(context.ref, value.ref, &exception) else {
    if let exception {
      return .exception(JSCValueHandle(ref: exception))
    }
    return .exception(javaScriptCoreMakeUndefined(in: context))
  }
  return .object(objectRef)
}

func javaScriptCoreResult(
  value resultRef: JSValueRef?,
  exception exceptionRef: JSValueRef?,
  in context: JSCContextHandle
) -> JSResult<JSCValueHandle> {
  if let exceptionRef {
    return .exception(JSCValueHandle(ref: exceptionRef))
  }
  if let resultRef {
    return .value(JSCValueHandle(ref: resultRef))
  }
  return .value(javaScriptCoreMakeUndefined(in: context))
}

func javaScriptCoreMakeUndefined(in context: JSCContextHandle)
  -> JSCValueHandle
{
  JSCValueHandle(ref: JSValueMakeUndefined(context.ref)!)
}

func javaScriptCoreMakeStringValue(
  _ value: String,
  in context: JSCContextHandle
) -> JSCValueHandle {
  guard !value.isEmpty else {
    return JSCValueHandle(
      ref: JSValueMakeString(context.ref, javaScriptCoreEmptyStringRef)!
    )
  }

  return withJavaScriptCoreString(value) { stringHandle in
    JSCValueHandle(
      ref: JSValueMakeString(context.ref, stringHandle)!
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
