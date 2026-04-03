extension JSEngine
where
  Self: _JSEngineRuntimeDriver,
  Self: _JSEnginePropertyDriver,
  Self: _JSEngineInvocationDriver,
  RawRuntime: Sendable,
  RawContext: Sendable,
  RawValue: Sendable,
  Engine.ValueHandle: JSValueManualReferenceCountedHandle,
  Engine.ValueHandle.RawValue == RawValue
{
  package static func propertyNamesForHandle(
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> [String]? {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return propertyNames(on: object.rawValue, in: rawContext)
  }

  package static func getStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return _resultHandle(from: getProperty(key, on: object.rawValue, in: rawContext))
  }

  package static func setStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    to value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch setProperty(
      key,
      on: object.rawValue,
      to: value.rawValue,
      in: rawContext,
      attributes: attributes
    ) {
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
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return _resultHandle(from: getProperty(key.rawValue, on: object.rawValue, in: rawContext))
  }

  package static func getIndexPropertyHandle(
    at index: UInt32,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return _resultHandle(from: getProperty(at: index, on: object.rawValue, in: rawContext))
  }

  package static func setValuePropertyHandle(
    _ key: JSValueHandle<Engine>,
    on object: JSValueHandle<Engine>,
    to value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch setProperty(
      key.rawValue,
      on: object.rawValue,
      to: value.rawValue,
      in: rawContext,
      attributes: attributes
    ) {
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
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch setProperty(at: index, on: object.rawValue, to: value.rawValue, in: rawContext) {
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
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return hasProperty(key, on: object.rawValue, in: rawContext)
  }

  package static func hasValuePropertyHandle(
    _ key: JSValueHandle<Engine>,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return hasProperty(key.rawValue, on: object.rawValue, in: rawContext)
  }

  package static func deleteStringPropertyHandle(
    _ key: String,
    on object: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch deleteProperty(key, on: object.rawValue, in: rawContext) {
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
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return false
    }

    switch deleteProperty(key.rawValue, on: object.rawValue, in: rawContext) {
    case .value:
      return true
    case .exception:
      return false
    }
  }
}
