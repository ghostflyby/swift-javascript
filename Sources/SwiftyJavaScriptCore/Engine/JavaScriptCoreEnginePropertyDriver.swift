import JavaScriptCore
import SwiftJavaScript

extension JavaScriptCoreEngine: JSEnginePropertyDriver {
  public static func makePropertyStringKeyHandle(
    _ value: String,
    in context: JavaScriptCoreContextHandle
  ) -> JavaScriptCorePropertyStringKeyHandle? {
    _ = context
    let keyRef = JSStringCreateWithCFString(value as CFString)!
    return JavaScriptCorePropertyStringKeyHandle(ref: keyRef)
  }

  public static func isPropertyStringKeyHandleCompatibleWithContext(
    _ key: JavaScriptCorePropertyStringKeyHandle,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    _ = key
    _ = context
    return true
  }

  public static func makeStringValueHandle(
    fromPropertyStringKey key: JavaScriptCorePropertyStringKeyHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSValueHandle<JavaScriptCoreEngine>? {
    JavaScriptCoreValueHandle(
      ref: JSValueMakeString(context.ref, key.ref)!,
      contextRef: context.ref
    )
  }

  public static func propertyNamesForHandle(
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> [String]? {
    propertyNames(on: object, in: context)
  }

  public static func getStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    withJavaScriptCoreString(key) { keyRef in
      getProperty(keyRef, on: object, in: context)
    }
  }

  public static func getPropertyStringKeyHandle(
    _ key: JavaScriptCorePropertyStringKeyHandle,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    getProperty(key.ref, on: object, in: context)
  }

  public static func setStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    to value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    withJavaScriptCoreString(key) { keyRef in
      switch setProperty(keyRef, on: object, to: value, in: context, attributes: attributes) {
      case .value:
        return true
      case .exception:
        return false
      }
    }
  }

  public static func setPropertyStringKeyHandle(
    _ key: JavaScriptCorePropertyStringKeyHandle,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    to value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    switch setProperty(key.ref, on: object, to: value, in: context, attributes: attributes) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  public static func getValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    getProperty(key, on: object, in: context)
  }

  public static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    getProperty(at: index, on: object, in: context)
  }

  public static func setValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    to value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    switch setProperty(key, on: object, to: value, in: context, attributes: attributes) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  public static func setIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    to value: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch setProperty(at: index, on: object, to: value, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  public static func hasPropertyStringKeyHandle(
    _ key: JavaScriptCorePropertyStringKeyHandle,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    hasProperty(key.ref, on: object, in: context)
  }

  public static func hasStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    withJavaScriptCoreString(key) { keyRef in
      hasProperty(keyRef, on: object, in: context)
    }
  }

  public static func hasValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    hasProperty(key, on: object, in: context)
  }

  public static func deletePropertyStringKeyHandle(
    _ key: JavaScriptCorePropertyStringKeyHandle,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch deleteProperty(key.ref, on: object, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  public static func deleteStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    withJavaScriptCoreString(key) { keyRef in
      switch deleteProperty(keyRef, on: object, in: context) {
      case .value:
        return true
      case .exception:
        return false
      }
    }
  }

  public static func deleteValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch deleteProperty(key, on: object, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  private static func propertyNames(
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> [String] {
    guard let propertyNamesFunction = context.propertyNamesFunctionRef else {
      return []
    }

    var exception: JSValueRef?
    var argument = Optional(object.ref)
    let namesValue = withUnsafePointer(to: &argument) { arguments in
      JSObjectCallAsFunction(
        context.ref,
        propertyNamesFunction,
        nil,
        1,
        arguments,
        &exception
      )
    }
    guard let namesValue, exception == nil else {
      return []
    }

    switch javaScriptCoreObjectRef(
      for: JavaScriptCoreValueHandle(ref: namesValue, contextRef: context.ref),
      in: context
    ) {
    case .exception:
      return []
    case .object(let namesArray):
      return arrayElements(from: namesArray, in: context)
    }
  }

  private static func arrayElements(
    from array: JSObjectRef,
    in context: JavaScriptCoreContextHandle
  ) -> [String] {
    let count = withJavaScriptCoreString("length") { lengthKey in
      var exception: JSValueRef?
      guard
        let lengthValue = JSObjectGetProperty(context.ref, array, lengthKey, &exception),
        exception == nil
      else {
        return 0
      }
      return Int(JSValueToNumber(context.ref, lengthValue, nil))
    }

    var result: [String] = []
    result.reserveCapacity(count)
    for index in 0..<count {
      var exception: JSValueRef?
      guard
        let value = JSObjectGetPropertyAtIndex(
          context.ref,
          array,
          UInt32(index),
          &exception
        ),
        exception == nil,
        let string = javaScriptCoreString(value, in: context.ref)
      else {
        continue
      }
      result.append(string)
    }
    return result
  }

  private static func getProperty(
    _ key: JSStringRef,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JavaScriptCoreValueHandle> {
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      var exception: JSValueRef?
      let valueRef = JSObjectGetProperty(context.ref, objectRef, key, &exception)
      return javaScriptCoreResult(value: valueRef, exception: exception, in: context)
    }
  }

  private static func getProperty(
    _ key: JavaScriptCoreValueHandle,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JavaScriptCoreValueHandle> {
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      var exception: JSValueRef?
      let valueRef = JSObjectGetPropertyForKey(context.ref, objectRef, key.ref, &exception)
      return javaScriptCoreResult(value: valueRef, exception: exception, in: context)
    }
  }

  private static func getProperty(
    at index: UInt32,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JavaScriptCoreValueHandle> {
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      var exception: JSValueRef?
      let valueRef = JSObjectGetPropertyAtIndex(context.ref, objectRef, index, &exception)
      return javaScriptCoreResult(value: valueRef, exception: exception, in: context)
    }
  }

  private static func setProperty(
    _ key: JSStringRef,
    on object: JavaScriptCoreValueHandle,
    to value: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle,
    attributes: JSHostMemberAttributes
  ) -> JSResult<Void> {
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      var exception: JSValueRef?
      JSObjectSetProperty(
        context.ref,
        objectRef,
        key,
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

  private static func setProperty(
    _ key: JavaScriptCoreValueHandle,
    on object: JavaScriptCoreValueHandle,
    to value: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle,
    attributes: JSHostMemberAttributes
  ) -> JSResult<Void> {
    switch javaScriptCoreObjectRef(for: object, in: context) {
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

  private static func setProperty(
    at index: UInt32,
    on object: JavaScriptCoreValueHandle,
    to value: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<Void> {
    switch javaScriptCoreObjectRef(for: object, in: context) {
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

  private static func hasProperty(
    _ key: JSStringRef,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception:
      return false
    case .object(let objectRef):
      return JSObjectHasProperty(context.ref, objectRef, key)
    }
  }

  private static func hasProperty(
    _ key: JavaScriptCoreValueHandle,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception:
      return false
    case .object(let objectRef):
      var exception: JSValueRef?
      let result = JSObjectHasPropertyForKey(context.ref, objectRef, key.ref, &exception)
      return exception == nil && result
    }
  }

  private static func deleteProperty(
    _ key: JSStringRef,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<Void> {
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      var exception: JSValueRef?
      JSObjectDeleteProperty(context.ref, objectRef, key, &exception)
      if exception != nil {
        return .exception(())
      }
      return .value(())
    }
  }

  private static func deleteProperty(
    _ key: JavaScriptCoreValueHandle,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<Void> {
    switch javaScriptCoreObjectRef(for: object, in: context) {
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
}
