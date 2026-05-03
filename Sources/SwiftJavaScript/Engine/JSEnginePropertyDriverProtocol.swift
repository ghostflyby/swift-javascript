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

  static func getPropertyStringKeyHandle(
    _ key: PropertyStringKeyHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> JSResult<ValueHandle>?

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
