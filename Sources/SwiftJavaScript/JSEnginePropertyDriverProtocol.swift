public protocol _JSEnginePropertyDriver: _JSEngineRuntimeDriver {
  static func propertyNamesForHandle(
    on object: ValueHandle,
    in context: ContextHandle
  ) -> [String]?

  static func getStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> JSDriverResult<ValueHandle>?

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
  ) -> JSDriverResult<ValueHandle>?

  static func getIndexPropertyHandle(
    at index: UInt32,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> JSDriverResult<ValueHandle>?

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

extension _JSEnginePropertyDriver {
  public static func propertyNamesForHandle(
    on object: ValueHandle,
    in context: ContextHandle
  ) -> [String]? {
    fatalError("_JSEnginePropertyDriver.propertyNamesForHandle(on:in:) is not implemented")
  }

  public static func getStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> JSDriverResult<ValueHandle>? {
    fatalError("_JSEnginePropertyDriver.getStringPropertyHandle(_:on:in:) is not implemented")
  }

  public static func setStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    to value: ValueHandle,
    in context: ContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    fatalError(
      "_JSEnginePropertyDriver.setStringPropertyHandle(_:on:to:in:attributes:) is not implemented"
    )
  }

  public static func getValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> JSDriverResult<ValueHandle>? {
    fatalError("_JSEnginePropertyDriver.getValuePropertyHandle(_:on:in:) is not implemented")
  }

  public static func getIndexPropertyHandle(
    at index: UInt32,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> JSDriverResult<ValueHandle>? {
    fatalError("_JSEnginePropertyDriver.getIndexPropertyHandle(at:on:in:) is not implemented")
  }

  public static func setValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle,
    to value: ValueHandle,
    in context: ContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    fatalError(
      "_JSEnginePropertyDriver.setValuePropertyHandle(_:on:to:in:attributes:) is not implemented"
    )
  }

  public static func setIndexPropertyHandle(
    at index: UInt32,
    on object: ValueHandle,
    to value: ValueHandle,
    in context: ContextHandle
  ) -> Bool {
    fatalError("_JSEnginePropertyDriver.setIndexPropertyHandle(at:on:to:in:) is not implemented")
  }

  public static func hasStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool? {
    fatalError("_JSEnginePropertyDriver.hasStringPropertyHandle(_:on:in:) is not implemented")
  }

  public static func hasValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool? {
    fatalError("_JSEnginePropertyDriver.hasValuePropertyHandle(_:on:in:) is not implemented")
  }

  public static func deleteStringPropertyHandle(
    _ key: String,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool {
    fatalError("_JSEnginePropertyDriver.deleteStringPropertyHandle(_:on:in:) is not implemented")
  }

  public static func deleteValuePropertyHandle(
    _ key: ValueHandle,
    on object: ValueHandle,
    in context: ContextHandle
  ) -> Bool {
    fatalError("_JSEnginePropertyDriver.deleteValuePropertyHandle(_:on:in:) is not implemented")
  }
}
