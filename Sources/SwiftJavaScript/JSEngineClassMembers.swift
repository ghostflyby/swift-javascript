public struct JSEngineStaticValue<E: JSEngine>: Sendable {
  public let name: String
  public let attributes: JSPropertyAttributes
  public let getProperty:
    @Sendable (borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>)
      -> JSResult<JSEngineValue<E>>

  public init(
    name: String,
    attributes: JSPropertyAttributes,
    getProperty:
      @escaping @Sendable (
        borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>
      ) -> JSResult<JSEngineValue<E>>,
    setProperty:
      @escaping @Sendable (
        borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>, borrowing JSEngineValue<E>
      ) -> JSResult<JSEngineValue<E>>
  ) {
    self.name = name
    self.attributes = attributes
    self.getProperty = getProperty
    self.setProperty = setProperty
  }
  public let setProperty:
    @Sendable (
      borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>, borrowing JSEngineValue<E>
    )
      -> JSResult<JSEngineValue<E>>
}

public struct JSEngineStaticFunction<E: JSEngine>: Sendable {
  public let name: String
  public let attributes: JSPropertyAttributes
  public let callAsFunction:
    @Sendable (
      borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>, borrowing JSArguments<E>
    ) -> JSResult<JSEngineValue<E>>

  public init(
    name: String,
    attributes: JSPropertyAttributes,
    callAsFunction:
      @escaping @Sendable (
        borrowing JSEngineInstantContext<E>, borrowing JSEngineValue<E>, borrowing JSArguments<E>
      ) -> JSResult<JSEngineValue<E>>
  ) {
    self.name = name
    self.attributes = attributes
    self.callAsFunction = callAsFunction
  }
}

extension JSEngineStaticValue {
  public func hostPropertyDescriptor(
    getterBinding: String? = nil,
    setterBinding: String? = nil
  ) -> JSHostPropertyDescriptor {
    JSHostPropertyDescriptor(
      name: name,
      attributes: attributes.hostMemberAttributes,
      getterBinding: getterBinding,
      setterBinding: setterBinding
    )
  }
}

extension JSEngineStaticFunction {
  public func hostFunctionDescriptor(binding: String? = nil) -> JSHostFunctionDescriptor {
    JSHostFunctionDescriptor(
      name: name,
      attributes: attributes.hostMemberAttributes,
      binding: binding
    )
  }
}
