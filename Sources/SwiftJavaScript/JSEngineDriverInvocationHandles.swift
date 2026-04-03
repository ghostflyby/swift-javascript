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
  package static func callFunctionHandle(
    _ function: JSValueHandle<Engine>,
    this thisValue: JSValueHandle<Engine>? = nil,
    arguments: [JSValueHandle<Engine>] = [],
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }

    let rawThisValue: RawValue? = thisValue?.rawValue
    let rawArguments = arguments.map(\.rawValue)

    return _resultHandle(
      from: callFunction(
        function.rawValue, this: rawThisValue, arguments: rawArguments, in: rawContext)
    )
  }

  package static func constructHandle(
    _ constructor: JSValueHandle<Engine>,
    arguments: [JSValueHandle<Engine>] = [],
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }

    let rawArguments = arguments.map(\.rawValue)

    return _resultHandle(
      from: construct(constructor.rawValue, arguments: rawArguments, in: rawContext)
    )
  }

  package static func toObjectHandle(
    _ value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> JSResultHandle<Engine>? {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }

    return _resultHandle(from: toObject(value.rawValue, in: rawContext))
  }

  package static func isArrayHandle(
    _ value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return isArray(value.rawValue, in: rawContext)
  }

  package static func isDateHandle(
    _ value: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return isDate(value.rawValue, in: rawContext)
  }

  package static func isInstanceOfHandle(
    _ value: JSValueHandle<Engine>,
    constructor: JSValueHandle<Engine>,
    in context: JSBorrowedContextHandle<Engine>
  ) -> Bool? {
    guard let rawContext: RawContext = context.opaqueHandle()
    else {
      return nil
    }
    return isInstanceOf(value.rawValue, constructor: constructor.rawValue, in: rawContext)
  }

  package static func _resultHandle(from result: JSDriverResult<RawValue>) -> JSResultHandle<Engine>
  {
    switch result {
    case .value(let rawValue):
      return .value(Engine.ValueHandle(rawValue: rawValue))
    case .exception(let rawValue):
      return .exception(Engine.ValueHandle(rawValue: rawValue))
    }
  }
}
