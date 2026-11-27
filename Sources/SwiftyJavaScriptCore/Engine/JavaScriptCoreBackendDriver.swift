import Foundation
import JavaScriptCore
import SwiftJavaScript

enum JavaScriptCoreObjectLookup {
  case object(JSObjectRef)
  case exception(JSValueRef)
}

package func javaScriptCoreContextGroupBits(
  for context: JSGlobalContextRef
) -> UInt? {
  UInt(bitPattern: JSContextGetGroup(context))
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
  for value: JSValueRef,
  in context: JSGlobalContextRef
) -> JavaScriptCoreObjectLookup {
  var exception: JSValueRef?
  guard let objectRef = JSValueToObject(context, value, &exception) else {
    if let exception {
      return .exception(exception)
    }
    return .exception(javaScriptCoreMakeUndefined(in: context))
  }
  return .object(objectRef)
}

func javaScriptCoreResult(
  value resultRef: JSValueRef?,
  exception exceptionRef: JSValueRef?,
  in context: JSGlobalContextRef
) -> JSResult<JSValueRef> {
  if let exceptionRef {
    return .exception(exceptionRef)
  }
  if let resultRef {
    return .value(resultRef)
  }
  return .value(javaScriptCoreMakeUndefined(in: context))
}

func javaScriptCoreMakeUndefined(in context: JSGlobalContextRef)
  -> JSValueRef
{
  JSValueMakeUndefined(context)
}

func javaScriptCoreMakeStringValue(
  _ value: String,
  in context: JSGlobalContextRef
) -> JSValueRef {
  guard !value.isEmpty else {
    return JSValueMakeString(context, javaScriptCoreEmptyStringRef)!
  }

  return withJavaScriptCoreString(value) { stringHandle in
    JSValueMakeString(context, stringHandle)!
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
