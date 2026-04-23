import JavaScriptCore
import SwiftJavaScript

extension JavaScriptCoreEngine: JSEnginePropertyDriver {
  public static func propertyNamesForHandle(
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> [String]? {
    propertyNames(on: object, in: context)
  }

  @_lifetime(immortal)
  public static func getStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    getProperty(key, on: object, in: context)
  }

  public static func setStringPropertyHandle(
    _ key: String,
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

  @_lifetime(immortal)
  public static func getValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JSValueHandle<JavaScriptCoreEngine>>? {
    getProperty(key, on: object, in: context)
  }

  @_lifetime(immortal)
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

  public static func hasStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    hasProperty(key, on: object, in: context)
  }

  public static func hasValuePropertyHandle(
    _ key: JSValueHandle<JavaScriptCoreEngine>,
    on object: JSValueHandle<JavaScriptCoreEngine>,
    in context: JavaScriptCoreContextHandle
  ) -> Bool? {
    hasProperty(key, on: object, in: context)
  }

  public static func deleteStringPropertyHandle(
    _ key: String,
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
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception:
      return []
    case .object(let objectRef):
      let names = JSObjectCopyPropertyNames(context.ref, objectRef)
      defer { JSPropertyNameArrayRelease(names) }

      let count = JSPropertyNameArrayGetCount(names)
      var result: [String] = []
      result.reserveCapacity(Int(count))
      for index in 0..<count {
        guard let keyHandle = JSPropertyNameArrayGetNameAtIndex(names, index) else {
          continue
        }
        result.append(
          String(
            jsStringHandle: JavaScriptCoreStringHandle(ref: keyHandle),
            engine: JavaScriptCoreEngine.self
          ))
      }
      return result
    }
  }

  @_lifetime(immortal)
  private static func getProperty(
    _ key: String,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<JavaScriptCoreValueHandle> {
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception(let exception):
      return .exception(exception)
    case .object(let objectRef):
      let keyRef = JSStringCreateWithCFString(key as CFString)!
      defer { JSStringRelease(keyRef) }
      var exception: JSValueRef?
      let valueRef = JSObjectGetProperty(context.ref, objectRef, keyRef, &exception)
      return javaScriptCoreResult(value: valueRef, exception: exception, in: context)
    }
  }

  @_lifetime(immortal)
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

  @_lifetime(immortal)
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

  @_lifetime(immortal)
  private static func setProperty(
    _ key: String,
    on object: JavaScriptCoreValueHandle,
    to value: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle,
    attributes: JSHostMemberAttributes
  ) -> JSResult<Void> {
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      let keyRef = JSStringCreateWithCFString(key as CFString)!
      defer { JSStringRelease(keyRef) }
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

  @_lifetime(immortal)
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

  @_lifetime(immortal)
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
    _ key: String,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> Bool {
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception:
      return false
    case .object(let objectRef):
      return withJavaScriptCoreString(key) { keyRef in
        JSObjectHasProperty(context.ref, objectRef, keyRef)
      }
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

  @_lifetime(immortal)
  private static func deleteProperty(
    _ key: String,
    on object: JavaScriptCoreValueHandle,
    in context: JavaScriptCoreContextHandle
  ) -> JSResult<Void> {
    switch javaScriptCoreObjectRef(for: object, in: context) {
    case .exception:
      return .exception(())
    case .object(let objectRef):
      let keyRef = JSStringCreateWithCFString(key as CFString)!
      defer { JSStringRelease(keyRef) }
      var exception: JSValueRef?
      JSObjectDeleteProperty(context.ref, objectRef, keyRef, &exception)
      if exception != nil {
        return .exception(())
      }
      return .value(())
    }
  }

  @_lifetime(immortal)
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
