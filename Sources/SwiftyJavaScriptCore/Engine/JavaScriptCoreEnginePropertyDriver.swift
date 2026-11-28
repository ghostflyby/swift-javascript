import JavaScriptCore
import SwiftJavaScript

package func javaScriptCoreMakePropertyStringKeyHandle(
  _ value: String,
  in context: JSGlobalContextRef
) -> JSStringRef? {
  _ = context
  let keyRef = JSStringCreateWithCFString(value as CFString)!
  return keyRef
}

package func javaScriptCoreMakePropertyStringKeyHandle(
  _ value: StaticString,
  in context: JSGlobalContextRef
) -> JSStringRef? {
  _ = context
  let keyRef = withJavaScriptCoreString(value) { keyRef in
    JSStringRetain(keyRef)!
  }
  return keyRef
}

package func javaScriptCoreMakeStringValueHandle(
  fromPropertyStringKey key: JSStringRef,
  in context: JSGlobalContextRef
) -> JSValueRef? {
  JSValueMakeString(context, key)!
}

package func javaScriptCorePropertyNamesForHandle(
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> [String]? {
  javaScriptCorePropertyNames(on: object, in: context)
}

package func javaScriptCoreGetStaticStringPropertyHandle(
  _ key: StaticString,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> JSResult<JSValueRef>? {
  withJavaScriptCoreString(key) { keyRef in
    javaScriptCoreGetStringProperty(keyRef, on: object, in: context)
  }
}

package func javaScriptCoreGetPropertyStringKeyHandle(
  _ key: JSStringRef,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> JSResult<JSValueRef>? {
  javaScriptCoreGetStringProperty(key, on: object, in: context)
}

package func javaScriptCoreSetStaticStringPropertyHandle(
  _ key: StaticString,
  on object: JSValueRef,
  to value: JSValueRef,
  in context: JSGlobalContextRef,
  attributes: JSHostMemberAttributes = .none
) -> Bool {
  withJavaScriptCoreString(key) { keyRef in
    switch javaScriptCoreSetStringProperty(
      keyRef, on: object, to: value, in: context, attributes: attributes)
    {
    case .value:
      return true
    case .exception:
      return false
    }
  }
}

package func javaScriptCoreSetPropertyStringKeyHandle(
  _ key: JSStringRef,
  on object: JSValueRef,
  to value: JSValueRef,
  in context: JSGlobalContextRef,
  attributes: JSHostMemberAttributes = .none
) -> Bool {
  switch javaScriptCoreSetStringProperty(
    key, on: object, to: value, in: context, attributes: attributes)
  {
  case .value:
    return true
  case .exception:
    return false
  }
}

package func javaScriptCoreGetValuePropertyHandle(
  _ key: JSValueRef,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> JSResult<JSValueRef>? {
  javaScriptCoreGetProperty(key, on: object, in: context)
}

package func javaScriptCoreGetIndexPropertyHandle(
  at index: UInt32,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> JSResult<JSValueRef>? {
  javaScriptCoreGetProperty(at: index, on: object, in: context)
}

package func javaScriptCoreSetValuePropertyHandle(
  _ key: JSValueRef,
  on object: JSValueRef,
  to value: JSValueRef,
  in context: JSGlobalContextRef,
  attributes: JSHostMemberAttributes = .none
) -> Bool {
  switch javaScriptCoreSetProperty(key, on: object, to: value, in: context, attributes: attributes)
  {
  case .value:
    return true
  case .exception:
    return false
  }
}

package func javaScriptCoreSetIndexPropertyHandle(
  at index: UInt32,
  on object: JSValueRef,
  to value: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool {
  switch javaScriptCoreSetProperty(at: index, on: object, to: value, in: context) {
  case .value:
    return true
  case .exception:
    return false
  }
}

package func javaScriptCoreHasPropertyStringKeyHandle(
  _ key: JSStringRef,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool? {
  javaScriptCoreHasStringProperty(key, on: object, in: context)
}

package func javaScriptCoreHasStaticStringPropertyHandle(
  _ key: StaticString,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool? {
  withJavaScriptCoreString(key) { keyRef in
    javaScriptCoreHasStringProperty(keyRef, on: object, in: context)
  }
}

package func javaScriptCoreHasValuePropertyHandle(
  _ key: JSValueRef,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool? {
  javaScriptCoreHasProperty(key, on: object, in: context)
}

package func javaScriptCoreDeletePropertyStringKeyHandle(
  _ key: JSStringRef,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool {
  switch javaScriptCoreDeleteStringProperty(key, on: object, in: context) {
  case .value:
    return true
  case .exception:
    return false
  }
}

package func javaScriptCoreDeleteStaticStringPropertyHandle(
  _ key: StaticString,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool {
  withJavaScriptCoreString(key) { keyRef in
    switch javaScriptCoreDeleteStringProperty(keyRef, on: object, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }
}

package func javaScriptCoreDeleteValuePropertyHandle(
  _ key: JSValueRef,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool {
  switch javaScriptCoreDeleteProperty(key, on: object, in: context) {
  case .value:
    return true
  case .exception:
    return false
  }
}

private func javaScriptCorePropertyNames(
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> [String] {
  switch javaScriptCoreObjectRef(for: object, in: context) {
  case .exception:
    return []
  case .object(let objectRef):
    guard let function = javaScriptCorePropertyNamesFunction(for: context) else {
      return []
    }
    var exception: JSValueRef?
    var argument = Optional(object)
    let namesValue = withUnsafePointer(to: &argument) { arguments in
      JSObjectCallAsFunction(
        context,
        function,
        nil,
        1,
        arguments,
        &exception
      )
    }
    guard let namesValue, exception == nil,
      case .object(let namesArray) = javaScriptCoreObjectRef(
        for: namesValue,
        in: context
      )
    else {
      return []
    }
    return javaScriptCoreArrayElements(from: namesArray, in: context)
  }
}

/// `Object.keys` returns own enumerable string keys; the raw
/// `JSObjectCopyPropertyNames` also returns non-enumerable ones.
package func javaScriptCoreMakePropertyNamesFunction(
  in context: JSGlobalContextRef
) -> JSObjectRef? {
  let source = """
    (function(keys) {
      return function(value) {
        return keys(value);
      };
    })(Object.keys)
    """
  return withJavaScriptCoreString(source) { scriptRef in
    var exception: JSValueRef?
    guard
      let value = JSEvaluateScript(context, scriptRef, nil, nil, 1, &exception),
      exception == nil
    else {
      return nil
    }
    return JSValueToObject(context, value, nil)
  }
}

private func javaScriptCoreArrayElements(
  from array: JSObjectRef,
  in context: JSGlobalContextRef
) -> [String] {
  let count = withJavaScriptCoreString("length") { lengthKey in
    var exception: JSValueRef?
    guard
      let lengthValue = JSObjectGetProperty(context, array, lengthKey, &exception),
      exception == nil
    else {
      return 0
    }
    return Int(JSValueToNumber(context, lengthValue, nil))
  }

  var result: [String] = []
  result.reserveCapacity(count)
  for index in 0..<count {
    var exception: JSValueRef?
    guard
      let value = JSObjectGetPropertyAtIndex(
        context,
        array,
        UInt32(index),
        &exception
      ),
      exception == nil,
      let string = javaScriptCoreString(value, in: context)
    else {
      continue
    }
    result.append(string)
  }
  return result
}

private func javaScriptCoreGetStringProperty(
  _ key: JSStringRef,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> JSResult<JSValueRef> {
  switch javaScriptCoreObjectRef(for: object, in: context) {
  case .exception(let exception):
    return .exception(exception)
  case .object(let objectRef):
    var exception: JSValueRef?
    let valueRef = JSObjectGetProperty(context, objectRef, key, &exception)
    return javaScriptCoreResult(value: valueRef, exception: exception, in: context)
  }
}

private func javaScriptCoreGetProperty(
  _ key: JSValueRef,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> JSResult<JSValueRef> {
  switch javaScriptCoreObjectRef(for: object, in: context) {
  case .exception(let exception):
    return .exception(exception)
  case .object(let objectRef):
    var exception: JSValueRef?
    let valueRef = JSObjectGetPropertyForKey(context, objectRef, key, &exception)
    return javaScriptCoreResult(value: valueRef, exception: exception, in: context)
  }
}

private func javaScriptCoreGetProperty(
  at index: UInt32,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> JSResult<JSValueRef> {
  switch javaScriptCoreObjectRef(for: object, in: context) {
  case .exception(let exception):
    return .exception(exception)
  case .object(let objectRef):
    var exception: JSValueRef?
    let valueRef = JSObjectGetPropertyAtIndex(context, objectRef, index, &exception)
    return javaScriptCoreResult(value: valueRef, exception: exception, in: context)
  }
}

private func javaScriptCoreSetStringProperty(
  _ key: JSStringRef,
  on object: JSValueRef,
  to value: JSValueRef,
  in context: JSGlobalContextRef,
  attributes: JSHostMemberAttributes
) -> JSResult<Void> {
  switch javaScriptCoreObjectRef(for: object, in: context) {
  case .exception:
    return .exception(())
  case .object(let objectRef):
    var exception: JSValueRef?
    JSObjectSetProperty(
      context,
      objectRef,
      key,
      value,
      javaScriptCorePropertyAttributes(from: attributes),
      &exception
    )
    if exception != nil {
      return .exception(())
    }
    return .value(())
  }
}

private func javaScriptCoreSetProperty(
  _ key: JSValueRef,
  on object: JSValueRef,
  to value: JSValueRef,
  in context: JSGlobalContextRef,
  attributes: JSHostMemberAttributes
) -> JSResult<Void> {
  switch javaScriptCoreObjectRef(for: object, in: context) {
  case .exception:
    return .exception(())
  case .object(let objectRef):
    var exception: JSValueRef?
    JSObjectSetPropertyForKey(
      context,
      objectRef,
      key,
      value,
      javaScriptCorePropertyAttributes(from: attributes),
      &exception
    )
    if exception != nil {
      return .exception(())
    }
    return .value(())
  }
}

private func javaScriptCoreSetProperty(
  at index: UInt32,
  on object: JSValueRef,
  to value: JSValueRef,
  in context: JSGlobalContextRef
) -> JSResult<Void> {
  switch javaScriptCoreObjectRef(for: object, in: context) {
  case .exception:
    return .exception(())
  case .object(let objectRef):
    var exception: JSValueRef?
    JSObjectSetPropertyAtIndex(context, objectRef, index, value, &exception)
    if exception != nil {
      return .exception(())
    }
    return .value(())
  }
}

private func javaScriptCoreHasStringProperty(
  _ key: JSStringRef,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool {
  switch javaScriptCoreObjectRef(for: object, in: context) {
  case .exception:
    return false
  case .object(let objectRef):
    return JSObjectHasProperty(context, objectRef, key)
  }
}

private func javaScriptCoreHasProperty(
  _ key: JSValueRef,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> Bool {
  switch javaScriptCoreObjectRef(for: object, in: context) {
  case .exception:
    return false
  case .object(let objectRef):
    var exception: JSValueRef?
    let result = JSObjectHasPropertyForKey(context, objectRef, key, &exception)
    return exception == nil && result
  }
}

private func javaScriptCoreDeleteStringProperty(
  _ key: JSStringRef,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> JSResult<Void> {
  switch javaScriptCoreObjectRef(for: object, in: context) {
  case .exception:
    return .exception(())
  case .object(let objectRef):
    var exception: JSValueRef?
    JSObjectDeleteProperty(context, objectRef, key, &exception)
    if exception != nil {
      return .exception(())
    }
    return .value(())
  }
}

private func javaScriptCoreDeleteProperty(
  _ key: JSValueRef,
  on object: JSValueRef,
  in context: JSGlobalContextRef
) -> JSResult<Void> {
  switch javaScriptCoreObjectRef(for: object, in: context) {
  case .exception:
    return .exception(())
  case .object(let objectRef):
    var exception: JSValueRef?
    JSObjectDeletePropertyForKey(context, objectRef, key, &exception)
    if exception != nil {
      return .exception(())
    }
    return .value(())
  }
}

// MARK: - Context-side driver conformance (Stage 2B)

package func javaScriptCorePropertyNamesFunction(
  for context: JSGlobalContextRef
) -> JSObjectRef? {
  if let cached = JSCContext.borrow(ctx: context)?.propertyNamesFunction {
    return cached
  }
  return javaScriptCoreMakePropertyNamesFunction(in: context)
}
