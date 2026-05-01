public protocol JSEnginePropertyDriver: JSEngineRuntimeDriver {
  associatedtype PropertyKeyHandle: JSPropertyKeyManualReferenceCountedHandle

  static func makePropertyKeyHandle(
    _ value: String,
    in context: ContextHandle
  ) -> PropertyKeyHandle?

  static func isPropertyKeyHandleCompatibleWithContext(
    _ key: PropertyKeyHandle,
    in context: ContextHandle
  ) -> Bool

  static func propertyNamesForHandle(
    on object: ValueHandle,
    in context: ContextHandle
  ) -> [String]?

  static func getPropertyKeyHandle(
    _ key: PropertyKeyHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> JSResult<ValueHandle>?

  static func setPropertyKeyHandle(
    _ key: PropertyKeyHandle,
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

  static func hasPropertyKeyHandle(
    _ key: PropertyKeyHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool?

  static func hasValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool?

  static func deletePropertyKeyHandle(
    _ key: PropertyKeyHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool

  static func deleteValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool
}
