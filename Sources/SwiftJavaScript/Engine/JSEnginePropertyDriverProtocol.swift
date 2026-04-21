public protocol JSEnginePropertyDriver: JSEngineRuntimeDriver {
  static func propertyNamesForHandle(
    on object: ValueHandle,
    in context: ContextHandle
  ) -> [String]?

  static func getStringPropertyHandle(
    _ key: String,
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

  static func deleteValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool
}
