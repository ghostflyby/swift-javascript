extension _JSEngineDriver where RawRuntime: Sendable, RawContext: Sendable, RawValue: Sendable {
  package static func propertyNamesForHandle(
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> [String]? {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return propertyNames(on: rawObject, in: rawContext)
  }

  package static func getStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return _resultHandle(from: getProperty(key, on: rawObject, in: rawContext))
  }

  package static func setStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    to value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawValue: RawValue = value.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch setProperty(key, on: rawObject, to: rawValue, in: rawContext, attributes: attributes) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func getValuePropertyHandle(
    _ key: JSValueHandle<Engine>,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawKey: RawValue = key.opaqueHandle(),
      let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return _resultHandle(from: getProperty(rawKey, on: rawObject, in: rawContext))
  }

  package static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return _resultHandle(from: getProperty(at: index, on: rawObject, in: rawContext))
  }

  package static func setValuePropertyHandle(
    _ key: JSValueHandle<Engine>,
    on object: JSValueHandle<Engine>,
    to value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    guard let rawKey: RawValue = key.opaqueHandle(),
      let rawObject: RawValue = object.opaqueHandle(),
      let rawValue: RawValue = value.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch setProperty(rawKey, on: rawObject, to: rawValue, in: rawContext, attributes: attributes)
    {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func setIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<Engine>,
    to value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawValue: RawValue = value.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch setProperty(at: index, on: rawObject, to: rawValue, in: rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func hasStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return hasProperty(key, on: rawObject, in: rawContext)
  }

  package static func hasValuePropertyHandle(
    _ key: JSValueHandle<Engine>,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawKey: RawValue = key.opaqueHandle(),
      let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return hasProperty(rawKey, on: rawObject, in: rawContext)
  }

  package static func deleteStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool {
    guard let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch deleteProperty(key, on: rawObject, in: rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }

  package static func deleteValuePropertyHandle(
    _ key: JSValueHandle<Engine>,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool {
    guard let rawKey: RawValue = key.opaqueHandle(),
      let rawObject: RawValue = object.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch deleteProperty(rawKey, on: rawObject, in: rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }
}
