import JavaScriptCore
import SwiftJavaScript

extension JSCEngine: JSEnginePropertyDriver {
  package static func makePropertyStringKeyHandle(
    _ value: String,
    in context: JSCContextHandle
  ) -> JSCPropertyStringKeyHandle? {
    _ = context
    let keyRef = JSStringCreateWithCFString(value as CFString)!
    return JSCPropertyStringKeyHandle(ref: keyRef)
  }

  package static func makePropertyStringKeyHandle(
    _ value: StaticString,
    in context: JSCContextHandle
  ) -> JSCPropertyStringKeyHandle? {
    _ = context
    let keyRef = withJavaScriptCoreString(value) { keyRef in
      JSStringRetain(keyRef)!
    }
    return JSCPropertyStringKeyHandle(ref: keyRef)
  }

  package static func isPropertyStringKeyHandleCompatibleWithContext(
    _ key: JSCPropertyStringKeyHandle,
    in context: JSCContextHandle
  ) -> Bool {
    _ = key
    _ = context
    return true
  }

  package static func makeStringValueHandle(
    fromPropertyStringKey key: JSCPropertyStringKeyHandle,
    in context: JSCContextHandle
  ) -> JSOwnedValueHandle<JSCEngine>? {
    JSCOwnedValueHandle(
      ref: JSValueMakeString(context.ref, key.ref)!
    )
  }

  package static func propertyNamesForHandle(
    on object: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> [String]? {
    propertyNames(on: object, in: context)
  }

  package static func getStaticStringPropertyHandle(
    _ key: StaticString,
    on object: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> JSResult<JSValueHandle<JSCEngine>>? {
    withJavaScriptCoreString(key) { keyRef in
      getProperty(keyRef, on: object, in: context)
    }
  }

  package static func getPropertyStringKeyHandle(
    _ key: JSCPropertyStringKeyHandle,
    on object: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> JSResult<JSValueHandle<JSCEngine>>? {
    getProperty(key.ref, on: object, in: context)
  }

  package static func setStaticStringPropertyHandle(
    _ key: StaticString,
    on object: JSValueHandle<JSCEngine>,
    to value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle,
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

  package static func setPropertyStringKeyHandle(
    _ key: JSCPropertyStringKeyHandle,
    on object: JSValueHandle<JSCEngine>,
    to value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    switch setProperty(key.ref, on: object, to: value, in: context, attributes: attributes) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func getValuePropertyHandle(
    _ key: JSValueHandle<JSCEngine>,
    on object: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> JSResult<JSValueHandle<JSCEngine>>? {
    getProperty(key, on: object, in: context)
  }

  package static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> JSResult<JSValueHandle<JSCEngine>>? {
    getProperty(at: index, on: object, in: context)
  }

  package static func setValuePropertyHandle(
    _ key: JSValueHandle<JSCEngine>,
    on object: JSValueHandle<JSCEngine>,
    to value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle,
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
    on object: JSValueHandle<JSCEngine>,
    to value: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool {
    switch setProperty(at: index, on: object, to: value, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func hasPropertyStringKeyHandle(
    _ key: JSCPropertyStringKeyHandle,
    on object: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    hasProperty(key.ref, on: object, in: context)
  }

  package static func hasStaticStringPropertyHandle(
    _ key: StaticString,
    on object: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    withJavaScriptCoreString(key) { keyRef in
      hasProperty(keyRef, on: object, in: context)
    }
  }

  package static func hasValuePropertyHandle(
    _ key: JSValueHandle<JSCEngine>,
    on object: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool? {
    hasProperty(key, on: object, in: context)
  }

  package static func deletePropertyStringKeyHandle(
    _ key: JSCPropertyStringKeyHandle,
    on object: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool {
    switch deleteProperty(key.ref, on: object, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func deleteStaticStringPropertyHandle(
    _ key: StaticString,
    on object: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
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

  package static func deleteValuePropertyHandle(
    _ key: JSValueHandle<JSCEngine>,
    on object: JSValueHandle<JSCEngine>,
    in context: JSCContextHandle
  ) -> Bool {
    switch deleteProperty(key, on: object, in: context) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  private static func propertyNames(
    on object: JSCValueHandle,
    in context: JSCContextHandle
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
      for: JSCValueHandle(ref: namesValue),
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
    in context: JSCContextHandle
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
    on object: JSCValueHandle,
    in context: JSCContextHandle
  ) -> JSResult<JSCValueHandle> {
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
    _ key: JSCValueHandle,
    on object: JSCValueHandle,
    in context: JSCContextHandle
  ) -> JSResult<JSCValueHandle> {
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
    on object: JSCValueHandle,
    in context: JSCContextHandle
  ) -> JSResult<JSCValueHandle> {
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
    on object: JSCValueHandle,
    to value: JSCValueHandle,
    in context: JSCContextHandle,
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
    _ key: JSCValueHandle,
    on object: JSCValueHandle,
    to value: JSCValueHandle,
    in context: JSCContextHandle,
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
    on object: JSCValueHandle,
    to value: JSCValueHandle,
    in context: JSCContextHandle
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
    on object: JSCValueHandle,
    in context: JSCContextHandle
  ) -> Bool {
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception:
      return false
    case .object(let objectRef):
      return JSObjectHasProperty(context.ref, objectRef, key)
    }
  }

  private static func hasProperty(
    _ key: JSCValueHandle,
    on object: JSCValueHandle,
    in context: JSCContextHandle
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
    on object: JSCValueHandle,
    in context: JSCContextHandle
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
    _ key: JSCValueHandle,
    on object: JSCValueHandle,
    in context: JSCContextHandle
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

// MARK: - Context-side driver conformance (Stage 2B)

extension JSCContextHandle: JSContextPropertyDriver {
  package typealias PropertyStringKeyHandle = JSCPropertyStringKeyHandle

  package func makePropertyStringKeyHandle(_ value: String)
    -> JSCPropertyStringKeyHandle?
  {
    JSCEngine.makePropertyStringKeyHandle(value, in: self)
  }

  package func makePropertyStringKeyHandle(_ value: StaticString)
    -> JSCPropertyStringKeyHandle?
  {
    JSCEngine.makePropertyStringKeyHandle(value, in: self)
  }

  package func isPropertyStringKeyHandleCompatibleWithContext(
    _ key: JSCPropertyStringKeyHandle
  ) -> Bool {
    JSCEngine.isPropertyStringKeyHandleCompatibleWithContext(key, in: self)
  }

  package func makeStringValueHandle(
    fromPropertyStringKey key: JSCPropertyStringKeyHandle
  ) -> JSCOwnedValueHandle? {
    JSCEngine.makeStringValueHandle(fromPropertyStringKey: key, in: self)
  }

  package func propertyNamesForHandle(on object: JSCValueHandle) -> [String]? {
    JSCEngine.propertyNamesForHandle(on: object, in: self)
  }

  package func getStaticStringPropertyHandle(
    _ key: StaticString,
    on object: JSCValueHandle
  ) -> JSResult<JSCValueHandle>? {
    JSCEngine.getStaticStringPropertyHandle(key, on: object, in: self)
  }

  package func setStaticStringPropertyHandle(
    _ key: StaticString,
    on object: JSCValueHandle,
    to value: JSCValueHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    JSCEngine.setStaticStringPropertyHandle(
      key,
      on: object,
      to: value,
      in: self,
      attributes: attributes
    )
  }

  package func getPropertyStringKeyHandle(
    _ key: JSCPropertyStringKeyHandle,
    on object: JSCValueHandle
  ) -> JSResult<JSCValueHandle>? {
    JSCEngine.getPropertyStringKeyHandle(key, on: object, in: self)
  }

  package func setPropertyStringKeyHandle(
    _ key: JSCPropertyStringKeyHandle,
    on object: JSCValueHandle,
    to value: JSCValueHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    JSCEngine.setPropertyStringKeyHandle(
      key,
      on: object,
      to: value,
      in: self,
      attributes: attributes
    )
  }

  package func getValuePropertyHandle(
    _ key: JSCValueHandle,
    on object: JSCValueHandle
  ) -> JSResult<JSCValueHandle>? {
    JSCEngine.getValuePropertyHandle(key, on: object, in: self)
  }

  package func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSCValueHandle
  ) -> JSResult<JSCValueHandle>? {
    JSCEngine.getIndexPropertyHandle(at: index, on: object, in: self)
  }

  package func setValuePropertyHandle(
    _ key: JSCValueHandle,
    on object: JSCValueHandle,
    to value: JSCValueHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    JSCEngine.setValuePropertyHandle(
      key,
      on: object,
      to: value,
      in: self,
      attributes: attributes
    )
  }

  package func setIndexPropertyHandle(
    at index: UInt32,
    on object: JSCValueHandle,
    to value: JSCValueHandle
  ) -> Bool {
    JSCEngine.setIndexPropertyHandle(at: index, on: object, to: value, in: self)
  }

  package func hasStaticStringPropertyHandle(
    _ key: StaticString,
    on object: JSCValueHandle
  ) -> Bool? {
    JSCEngine.hasStaticStringPropertyHandle(key, on: object, in: self)
  }

  package func hasPropertyStringKeyHandle(
    _ key: JSCPropertyStringKeyHandle,
    on object: JSCValueHandle
  ) -> Bool? {
    JSCEngine.hasPropertyStringKeyHandle(key, on: object, in: self)
  }

  package func hasValuePropertyHandle(
    _ key: JSCValueHandle,
    on object: JSCValueHandle
  ) -> Bool? {
    JSCEngine.hasValuePropertyHandle(key, on: object, in: self)
  }

  package func deleteStaticStringPropertyHandle(
    _ key: StaticString,
    on object: JSCValueHandle
  ) -> Bool {
    JSCEngine.deleteStaticStringPropertyHandle(key, on: object, in: self)
  }

  package func deletePropertyStringKeyHandle(
    _ key: JSCPropertyStringKeyHandle,
    on object: JSCValueHandle
  ) -> Bool {
    JSCEngine.deletePropertyStringKeyHandle(key, on: object, in: self)
  }

  package func deleteValuePropertyHandle(
    _ key: JSCValueHandle,
    on object: JSCValueHandle
  ) -> Bool {
    JSCEngine.deleteValuePropertyHandle(key, on: object, in: self)
  }
}
