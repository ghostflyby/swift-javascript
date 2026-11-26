import JavaScriptCore
import SwiftJavaScript

extension JSCEngine {
  package static func makePropertyStringKeyHandle(
    _ value: String,
    in context: JSGlobalContextRef
  ) -> JSStringRef? {
    _ = context
    let keyRef = JSStringCreateWithCFString(value as CFString)!
    return keyRef
  }

  package static func makePropertyStringKeyHandle(
    _ value: StaticString,
    in context: JSGlobalContextRef
  ) -> JSStringRef? {
    _ = context
    let keyRef = withJavaScriptCoreString(value) { keyRef in
      JSStringRetain(keyRef)!
    }
    return keyRef
  }

  package static func isPropertyStringKeyHandleCompatibleWithContext(
    _ key: JSStringRef,
    in context: JSGlobalContextRef
  ) -> Bool {
    _ = key
    _ = context
    return true
  }

  package static func makeStringValueHandle(
    fromPropertyStringKey key: JSStringRef,
    in context: JSGlobalContextRef
  ) -> JSValueRef? {
    JSValueMakeString(context, key)!
  }

  package static func propertyNamesForHandle(
    on object: JSValueRef,
    in context: JSGlobalContextRef
  ) -> [String]? {
    propertyNames(on: object, in: context)
  }

  package static func getStaticStringPropertyHandle(
    _ key: StaticString,
    on object: JSValueRef,
    in context: JSGlobalContextRef
  ) -> JSResult<JSValueRef>? {
    withJavaScriptCoreString(key) { keyRef in
      getStringProperty(keyRef, on: object, in: context)
    }
  }

  package static func getPropertyStringKeyHandle(
    _ key: JSStringRef,
    on object: JSValueRef,
    in context: JSGlobalContextRef
  ) -> JSResult<JSValueRef>? {
    getStringProperty(key, on: object, in: context)
  }

  package static func setStaticStringPropertyHandle(
    _ key: StaticString,
    on object: JSValueRef,
    to value: JSValueRef,
    in context: JSGlobalContextRef,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    withJavaScriptCoreString(key) { keyRef in
      switch setStringProperty(keyRef, on: object, to: value, in: context, attributes: attributes) {
      case .value:
        return true
      case .exception:
        return false
      }
    }
  }

  package static func setPropertyStringKeyHandle(
    _ key: JSStringRef,
    on object: JSValueRef,
    to value: JSValueRef,
    in context: JSGlobalContextRef,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    switch setStringProperty(key, on: object, to: value, in: context, attributes: attributes) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func getValuePropertyHandle(
    _ key: JSValueRef,
    on object: JSValueRef,
    in context: JSGlobalContextRef
  ) -> JSResult<JSValueRef>? {
    getProperty(key, on: object, in: context)
  }

  package static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueRef,
    in context: JSGlobalContextRef
  ) -> JSResult<JSValueRef>? {
    getProperty(at: index, on: object, in: context)
  }

  package static func setValuePropertyHandle(
    _ key: JSValueRef,
    on object: JSValueRef,
    to value: JSValueRef,
    in context: JSGlobalContextRef,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    switch setProperty(key, on: object, to: value, in: context, attributes: attributes) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func setIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueRef,
    to value: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool {
    switch setProperty(at: index, on: object, to: value, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func hasPropertyStringKeyHandle(
    _ key: JSStringRef,
    on object: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool? {
    hasStringProperty(key, on: object, in: context)
  }

  package static func hasStaticStringPropertyHandle(
    _ key: StaticString,
    on object: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool? {
    withJavaScriptCoreString(key) { keyRef in
      hasStringProperty(keyRef, on: object, in: context)
    }
  }

  package static func hasValuePropertyHandle(
    _ key: JSValueRef,
    on object: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool? {
    hasProperty(key, on: object, in: context)
  }

  package static func deletePropertyStringKeyHandle(
    _ key: JSStringRef,
    on object: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool {
    switch deleteStringProperty(key, on: object, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func deleteStaticStringPropertyHandle(
    _ key: StaticString,
    on object: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool {
    withJavaScriptCoreString(key) { keyRef in
      switch deleteStringProperty(keyRef, on: object, in: context) {
      case .value:
        return true
      case .exception:
        return false
      }
    }
  }

  package static func deleteValuePropertyHandle(
    _ key: JSValueRef,
    on object: JSValueRef,
    in context: JSGlobalContextRef
  ) -> Bool {
    switch deleteProperty(key, on: object, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  private static func propertyNames(
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
      return arrayElements(from: namesArray, in: context)
    }
  }

  /// `Object.keys` returns own enumerable string keys; the raw
  /// `JSObjectCopyPropertyNames` also returns non-enumerable ones.
  package static func makePropertyNamesFunction(
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

  private static func arrayElements(
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

  private static func getStringProperty(
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

  private static func getProperty(
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

  private static func getProperty(
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

  private static func setStringProperty(
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

  private static func setProperty(
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

  private static func setProperty(
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

  private static func hasStringProperty(
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

  private static func hasProperty(
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

  private static func deleteStringProperty(
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

  private static func deleteProperty(
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
}

// MARK: - Context-side driver conformance (Stage 2B)

package func javaScriptCorePropertyNamesFunction(
  for context: JSGlobalContextRef
) -> JSObjectRef? {
  if let cached = JSCContext.borrow(ctx: context)?.propertyNamesFunction {
    return cached
  }
  return JSCEngine.makePropertyNamesFunction(in: context)
}
