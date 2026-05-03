public protocol JSEnginePropertyDriver: JSEngineRuntimeDriver {
  associatedtype PropertyStringKeyHandle: JSPropertyStringKeyManualReferenceCountedHandle

  static func makePropertyStringKeyHandle(
    _ value: String,
    in context: ContextHandle
  ) -> PropertyStringKeyHandle?

  static func isPropertyStringKeyHandleCompatibleWithContext(
    _ key: PropertyStringKeyHandle,
    in context: ContextHandle
  ) -> Bool

  static func makeStringValueHandle(
    fromPropertyStringKey key: PropertyStringKeyHandle,
    in context: ContextHandle
  ) -> ValueHandle?

  static func propertyNamesForHandle(
    on object: ValueHandle,
    in context: ContextHandle
  ) -> [String]?

  static func getStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> JSResult<ValueHandle>?

  static func getPropertyStringKeyHandle(
    _ key: PropertyStringKeyHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> JSResult<ValueHandle>?

  static func setStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    to value: ValueHandle,
    in context: ContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool

  static func setPropertyStringKeyHandle(
    _ key: PropertyStringKeyHandle,
    on object: ValueHandle,
    to value: ValueHandle,
    in context: ContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool

  static func getValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> JSResult<ValueHandle>?

  static func getIndexPropertyHandle(
    at index: UInt32,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> JSResult<ValueHandle>?

  static func setValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle,
    to value: ValueHandle,
    in context: ContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool

  static func setIndexPropertyHandle(
    at index: UInt32,
    on object: ValueHandle,
    to value: ValueHandle,
    in context: ContextHandle
  ) -> Bool

  static func hasStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool?

  static func hasPropertyStringKeyHandle(
    _ key: PropertyStringKeyHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool?

  static func hasValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool?

  static func deleteStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool

  static func deletePropertyStringKeyHandle(
    _ key: PropertyStringKeyHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool

  static func deleteValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool
}

extension JSEnginePropertyDriver {
  public static func getStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> JSResult<ValueHandle>? {
    guard let keyHandle = makePropertyStringKeyHandle(key, in: context) else {
      return nil
    }
    defer { _ = keyHandle.releaseReference() }
    return getPropertyStringKeyHandle(keyHandle, on: object, in: context)
  }

  public static func setStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    to value: ValueHandle,
    in context: ContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    guard let keyHandle = makePropertyStringKeyHandle(key, in: context) else {
      return false
    }
    defer { _ = keyHandle.releaseReference() }
    return setPropertyStringKeyHandle(
      keyHandle,
      on: object,
      to: value,
      in: context,
      attributes: attributes
    )
  }

  public static func hasStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool? {
    guard let keyHandle = makePropertyStringKeyHandle(key, in: context) else {
      return nil
    }
    defer { _ = keyHandle.releaseReference() }
    return hasPropertyStringKeyHandle(keyHandle, on: object, in: context)
  }

  public static func deleteStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool {
    guard let keyHandle = makePropertyStringKeyHandle(key, in: context) else {
      return false
    }
    defer { _ = keyHandle.releaseReference() }
    return deletePropertyStringKeyHandle(keyHandle, on: object, in: context)
  }
}
