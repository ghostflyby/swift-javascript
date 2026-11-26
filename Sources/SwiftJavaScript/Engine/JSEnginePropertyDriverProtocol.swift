/// Context-side property operations (Stage 2B decomposition).
package protocol JSContextPropertyDriver: JSContextRuntimeDriver {
  associatedtype PropertyStringKeyHandle: JSPropertyStringKeyManualReferenceCountedHandle

  func makePropertyStringKeyHandle(_ value: String) -> PropertyStringKeyHandle?

  func makePropertyStringKeyHandle(_ value: StaticString) -> PropertyStringKeyHandle?

  func isPropertyStringKeyHandleCompatibleWithContext(_ key: PropertyStringKeyHandle) -> Bool

  /// Creation factory (owned result): the engine produces a new owning
  /// reference for the property-string key's value.
  func makeStringValueHandle(fromPropertyStringKey key: PropertyStringKeyHandle)
    -> OwnedValueHandle?

  func propertyNamesForHandle(on object: ValueHandle) -> [String]?

  func getStaticStringPropertyHandle(
    _ key: StaticString,
    on object: ValueHandle
  ) -> JSResult<ValueHandle>?

  func getPropertyStringKeyHandle(
    _ key: PropertyStringKeyHandle,
    on object: ValueHandle
  ) -> JSResult<ValueHandle>?

  func setStaticStringPropertyHandle(
    _ key: StaticString,
    on object: ValueHandle,
    to value: ValueHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool

  func setPropertyStringKeyHandle(
    _ key: PropertyStringKeyHandle,
    on object: ValueHandle,
    to value: ValueHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool

  func getValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle
  ) -> JSResult<ValueHandle>?

  func getIndexPropertyHandle(
    at index: UInt32,
    on object: ValueHandle
  ) -> JSResult<ValueHandle>?

  func setValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle,
    to value: ValueHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool

  func setIndexPropertyHandle(
    at index: UInt32,
    on object: ValueHandle,
    to value: ValueHandle
  ) -> Bool

  func hasStaticStringPropertyHandle(
    _ key: StaticString,
    on object: ValueHandle
  ) -> Bool?

  func hasPropertyStringKeyHandle(
    _ key: PropertyStringKeyHandle,
    on object: ValueHandle
  ) -> Bool?

  func hasValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle
  ) -> Bool?

  func deleteStaticStringPropertyHandle(
    _ key: StaticString,
    on object: ValueHandle
  ) -> Bool

  func deletePropertyStringKeyHandle(
    _ key: PropertyStringKeyHandle,
    on object: ValueHandle
  ) -> Bool

  func deleteValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle
  ) -> Bool
}

extension JSContextPropertyDriver {
  package func getStaticStringPropertyHandle(
    _ key: StaticString,
    on object: ValueHandle
  ) -> JSResult<ValueHandle>? {
    guard let keyHandle = makePropertyStringKeyHandle(key) else {
      return nil
    }
    defer { _ = keyHandle.releaseReference() }
    return getPropertyStringKeyHandle(keyHandle, on: object)
  }

  package func setStaticStringPropertyHandle(
    _ key: StaticString,
    on object: ValueHandle,
    to value: ValueHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    guard let keyHandle = makePropertyStringKeyHandle(key) else {
      return false
    }
    defer { _ = keyHandle.releaseReference() }
    return setPropertyStringKeyHandle(
      keyHandle,
      on: object,
      to: value,
      attributes: attributes
    )
  }

  package func hasStaticStringPropertyHandle(
    _ key: StaticString,
    on object: ValueHandle
  ) -> Bool? {
    guard let keyHandle = makePropertyStringKeyHandle(key) else {
      return nil
    }
    defer { _ = keyHandle.releaseReference() }
    return hasPropertyStringKeyHandle(keyHandle, on: object)
  }

  package func deleteStaticStringPropertyHandle(
    _ key: StaticString,
    on object: ValueHandle
  ) -> Bool {
    guard let keyHandle = makePropertyStringKeyHandle(key) else {
      return false
    }
    defer { _ = keyHandle.releaseReference() }
    return deletePropertyStringKeyHandle(keyHandle, on: object)
  }
}

/// Engine-side descriptor. Property requirements now live on
/// `JSContextPropertyDriver`, implemented by `ContextHandle`.
package protocol JSEnginePropertyDriver: JSEngineRuntimeDriver
where
  ContextHandle: JSContextPropertyDriver,
  ContextHandle.PropertyStringKeyHandle == PropertyStringKeyHandle
{
  associatedtype PropertyStringKeyHandle: JSPropertyStringKeyManualReferenceCountedHandle
}
