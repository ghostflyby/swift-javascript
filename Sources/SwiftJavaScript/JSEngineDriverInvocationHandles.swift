extension _JSEngineDriver where RawRuntime: Sendable, RawContext: Sendable, RawValue: Sendable {
  package static func callFunctionHandle(
    _ function: JSValueHandle<Engine>,
    this thisValue: JSValueHandle<Engine>? = nil,
    arguments: [JSValueHandle<Engine>] = [],
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawFunction: RawValue = function.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }

    let rawThisValue: RawValue? = thisValue?.opaqueHandle()
    let rawArguments = arguments.compactMap { $0.opaqueHandle(as: RawValue.self) }
    guard rawArguments.count == arguments.count else {
      return nil
    }

    return _resultHandle(
      from: callFunction(rawFunction, this: rawThisValue, arguments: rawArguments, in: rawContext)
    )
  }

  package static func constructHandle(
    _ constructor: JSValueHandle<Engine>,
    arguments: [JSValueHandle<Engine>] = [],
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawConstructor: RawValue = constructor.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }

    let rawArguments = arguments.compactMap { $0.opaqueHandle(as: RawValue.self) }
    guard rawArguments.count == arguments.count else {
      return nil
    }

    return _resultHandle(from: construct(rawConstructor, arguments: rawArguments, in: rawContext))
  }

  package static func toObjectHandle(
    _ value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawValue: RawValue = value.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }

    return _resultHandle(from: toObject(rawValue, in: rawContext))
  }

  package static func isArrayHandle(
    _ value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawValue: RawValue = value.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return isArray(rawValue, in: rawContext)
  }

  package static func isDateHandle(
    _ value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawValue: RawValue = value.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return isDate(rawValue, in: rawContext)
  }

  package static func isInstanceOfHandle(
    _ value: JSValueHandle<Engine>,
    constructor: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawValue: RawValue = value.opaqueHandle(),
      let rawConstructor: RawValue = constructor.opaqueHandle(),
      let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return isInstanceOf(rawValue, constructor: rawConstructor, in: rawContext)
  }

  package static func _resultHandle(from result: JSDriverResult<RawValue>) -> JSResultHandle<Engine>
  {
    switch result {
    case .value(let rawValue):
      return .value(JSValueHandle<Engine>(_opaqueHandle: rawValue))
    case .exception(let rawValue):
      return .exception(JSValueHandle<Engine>(_opaqueHandle: rawValue))
    }
  }
}
