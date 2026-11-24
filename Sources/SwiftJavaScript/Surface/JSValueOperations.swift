// MARK: - Shared result bridging
//
// Value operations return engine-created handles. The shared surface bridges
// them into the engine's value view while tracking the creation reference on
// the arena of the scope (or the context default scope) that owns it, so the
// exception path settles exactly like the value path instead of dropping the
// handle.

package func bridgeSurfaceHandleResult<C: JSValueScope & ~Copyable>(
  _ result: JSResult<C.ContextHandle.ValueHandle>?,
  in context: borrowing C
) -> JSResult<C.Value> {
  guard let result else {
    preconditionFailure("JSValue operation unexpectedly returned nil")
  }
  switch consume result {
  case .value(let handle):
    return .value(context.adoptCreatedHandle(C.ContextHandle.OwnedValueHandle.adopting(handle)))
  case .exception(let handle):
    return .exception(context.adoptCreatedHandle(C.ContextHandle.OwnedValueHandle.adopting(handle)))
  }
}

package func bridgeSurfaceHandleResult<C: JSContext>(
  _ result: JSResult<C.ContextHandle.ValueHandle>?,
  in context: isolated C
) -> JSResult<C.Value> {
  guard let result else {
    preconditionFailure("JSValue operation unexpectedly returned nil")
  }
  switch consume result {
  case .value(let handle):
    return .value(context.adoptCreatedHandle(C.ContextHandle.OwnedValueHandle.adopting(handle)))
  case .exception(let handle):
    return .exception(context.adoptCreatedHandle(C.ContextHandle.OwnedValueHandle.adopting(handle)))
  }
}

// MARK: - Sync defaults
//
// These witness the `JSValue` requirements for conformers that do not add an
// engine-specific direct path (mocks and test values). Engine value types
// implement the same signatures against their own context driver.

extension JSValue where Self: ~Copyable {
  public func getProperty(
    _ key: StaticString,
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.getStaticStringPropertyHandle(key, on: borrowHandle()),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.getPropertyStringKeyHandle(
        key.borrowHandle(in: context.driverContextHandle),
        on: borrowHandle()
      ),
      in: context
    )
  }

  public func setProperty(
    _ key: StaticString,
    to value: borrowing Self,
    attributes: JSHostMemberAttributes,
    in context: borrowing InstantContext
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: borrowHandle(),
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    to value: borrowing Self,
    attributes: JSHostMemberAttributes,
    in context: borrowing InstantContext
  ) -> Bool {
    context.driverContextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: context.driverContextHandle),
      on: borrowHandle(),
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func deleteProperty(
    _ key: StaticString,
    in context: borrowing InstantContext
  ) -> Bool {
    context.driverContextHandle.deleteStaticStringPropertyHandle(key, on: borrowHandle())
  }

  public func deleteProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    in context: borrowing InstantContext
  ) -> Bool {
    context.driverContextHandle.deletePropertyStringKeyHandle(
      key.borrowHandle(in: context.driverContextHandle),
      on: borrowHandle()
    )
  }

  public func hasProperty(
    _ key: StaticString,
    in context: borrowing InstantContext
  ) -> Bool {
    context.driverContextHandle.hasStaticStringPropertyHandle(key, on: borrowHandle()) ?? false
  }

  public func hasProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    in context: borrowing InstantContext
  ) -> Bool {
    context.driverContextHandle.hasPropertyStringKeyHandle(
      key.borrowHandle(in: context.driverContextHandle),
      on: borrowHandle()
    ) ?? false
  }

  public func propertyNames(in context: borrowing InstantContext) -> [String] {
    context.driverContextHandle.propertyNamesForHandle(on: borrowHandle()) ?? []
  }

  public func call(
    arguments: [ValueHandle],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        borrowHandle(),
        this: nil,
        arguments: arguments
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing Self,
    arguments: [ValueHandle],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        borrowHandle(),
        this: thisValue.borrowHandle(),
        arguments: arguments
      ),
      in: context
    )
  }

  public func construct(
    arguments: [ValueHandle],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.constructHandle(borrowHandle(), arguments: arguments),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [ValueHandle],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value> {
    switch bridgeSurfaceHandleResult(
      context.driverContextHandle.getStaticStringPropertyHandle(name, on: borrowHandle()),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeSurfaceHandleResult(
        context.driverContextHandle.callFunctionHandle(
          method.borrowHandle(),
          this: borrowHandle(),
          arguments: arguments
        ),
        in: context
      )
    }
  }

  public func invokeMethod(
    _ name: borrowing InstantContext.PropertyStringKey,
    arguments: [ValueHandle],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value> {
    switch bridgeSurfaceHandleResult(
      context.driverContextHandle.getPropertyStringKeyHandle(
        name.borrowHandle(in: context.driverContextHandle),
        on: borrowHandle()
      ),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeSurfaceHandleResult(
        context.driverContextHandle.callFunctionHandle(
          method.borrowHandle(),
          this: borrowHandle(),
          arguments: arguments
        ),
        in: context
      )
    }
  }

  public func toObject(in context: borrowing InstantContext) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.toObjectHandle(borrowHandle()),
      in: context
    )
  }

  public func isArray(in context: borrowing InstantContext) -> Bool {
    context.driverContextHandle.isArrayHandle(borrowHandle()) ?? false
  }

  public func isDate(in context: borrowing InstantContext) -> Bool {
    context.driverContextHandle.isDateHandle(borrowHandle()) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing Self,
    in context: borrowing InstantContext
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      borrowHandle(),
      constructor: constructor.borrowHandle()
    ) ?? false
  }

  public func isArrayBuffer(in context: borrowing InstantContext) -> Bool {
    context.driverContextHandle.isArrayBufferHandle(borrowHandle())
  }

  public func isTypedArray(in context: borrowing InstantContext) -> Bool {
    context.driverContextHandle.typedArrayKindForHandle(borrowHandle()) != nil
  }

  // MARK: Callback-value parameters
  //
  // A callback window's value view is only an identity, so the operations that
  // consume an argument value accept it directly and borrow its handle.

  public func setProperty(
    _ key: StaticString,
    to value: borrowing InstantContext.CallbackValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing InstantContext
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: borrowHandle(),
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    to value: borrowing InstantContext.CallbackValue,
    attributes: JSHostMemberAttributes,
    in context: borrowing InstantContext
  ) -> Bool {
    context.driverContextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: context.driverContextHandle),
      on: borrowHandle(),
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func call(
    this thisValue: borrowing InstantContext.CallbackValue,
    arguments: [ValueHandle],
    in context: borrowing InstantContext
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        borrowHandle(),
        this: thisValue.borrowHandle(),
        arguments: arguments
      ),
      in: context
    )
  }

  public func isInstanceOf(
    _ constructor: borrowing InstantContext.CallbackValue,
    in context: borrowing InstantContext
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      borrowHandle(),
      constructor: constructor.borrowHandle()
    ) ?? false
  }
}

// MARK: - `#isolation` conveniences (S5)
//
// Every operation is also available addressed through the engine's context
// actor. The requirement cannot carry a default argument, so these same-name
// overloads are what keep `value.getProperty("x")` callable: the actor they
// run on supplies both the driver context and the default-scope adoption.

extension JSValue where Self: ~Copyable {
  // MARK: Property reads

  public func getProperty(
    _ key: StaticString,
    in context: isolated Context = #isolation
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.getStaticStringPropertyHandle(key, on: borrowHandle()),
      in: context
    )
  }

  public func getProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    in context: isolated Context = #isolation
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.getPropertyStringKeyHandle(
        key.borrowHandle(in: context.driverContextHandle),
        on: borrowHandle()
      ),
      in: context
    )
  }

  // MARK: Property writes

  public func setProperty(
    _ key: StaticString,
    to value: borrowing Self,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated Context = #isolation
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: borrowHandle(),
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    to value: borrowing Self,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated Context = #isolation
  ) -> Bool {
    context.driverContextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: context.driverContextHandle),
      on: borrowHandle(),
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  // MARK: Property removal and existence

  public func deleteProperty(
    _ key: StaticString,
    in context: isolated Context = #isolation
  ) -> Bool {
    context.driverContextHandle.deleteStaticStringPropertyHandle(key, on: borrowHandle())
  }

  public func deleteProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    in context: isolated Context = #isolation
  ) -> Bool {
    context.driverContextHandle.deletePropertyStringKeyHandle(
      key.borrowHandle(in: context.driverContextHandle),
      on: borrowHandle()
    )
  }

  public func hasProperty(
    _ key: StaticString,
    in context: isolated Context = #isolation
  ) -> Bool {
    context.driverContextHandle.hasStaticStringPropertyHandle(key, on: borrowHandle()) ?? false
  }

  public func hasProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    in context: isolated Context = #isolation
  ) -> Bool {
    context.driverContextHandle.hasPropertyStringKeyHandle(
      key.borrowHandle(in: context.driverContextHandle),
      on: borrowHandle()
    ) ?? false
  }

  public func propertyNames(
    in context: isolated Context = #isolation
  ) -> [String] {
    context.driverContextHandle.propertyNamesForHandle(on: borrowHandle()) ?? []
  }

  // MARK: Calling and construction

  public func call(
    arguments: [ValueHandle] = [],
    in context: isolated Context = #isolation
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        borrowHandle(),
        this: nil,
        arguments: arguments
      ),
      in: context
    )
  }

  public func call(
    this thisValue: borrowing Self,
    arguments: [ValueHandle] = [],
    in context: isolated Context = #isolation
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        borrowHandle(),
        this: thisValue.borrowHandle(),
        arguments: arguments
      ),
      in: context
    )
  }

  public func construct(
    arguments: [ValueHandle] = [],
    in context: isolated Context = #isolation
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.constructHandle(borrowHandle(), arguments: arguments),
      in: context
    )
  }

  public func invokeMethod(
    _ name: StaticString,
    arguments: [ValueHandle] = [],
    in context: isolated Context = #isolation
  ) -> JSResult<Context.Value> {
    switch bridgeSurfaceHandleResult(
      context.driverContextHandle.getStaticStringPropertyHandle(name, on: borrowHandle()),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeSurfaceHandleResult(
        context.driverContextHandle.callFunctionHandle(
          method.borrowHandle(),
          this: borrowHandle(),
          arguments: arguments
        ),
        in: context
      )
    }
  }

  public func invokeMethod(
    _ name: borrowing InstantContext.PropertyStringKey,
    arguments: [ValueHandle] = [],
    in context: isolated Context = #isolation
  ) -> JSResult<Context.Value> {
    switch bridgeSurfaceHandleResult(
      context.driverContextHandle.getPropertyStringKeyHandle(
        name.borrowHandle(in: context.driverContextHandle),
        on: borrowHandle()
      ),
      in: context
    ) {
    case .exception(let exception):
      return .exception(exception)
    case .value(let method):
      return bridgeSurfaceHandleResult(
        context.driverContextHandle.callFunctionHandle(
          method.borrowHandle(),
          this: borrowHandle(),
          arguments: arguments
        ),
        in: context
      )
    }
  }

  // MARK: Object conversion and classification

  public func toObject(
    in context: isolated Context = #isolation
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.toObjectHandle(borrowHandle()),
      in: context
    )
  }

  public func isArray(in context: isolated Context = #isolation) -> Bool {
    context.driverContextHandle.isArrayHandle(borrowHandle()) ?? false
  }

  public func isDate(in context: isolated Context = #isolation) -> Bool {
    context.driverContextHandle.isDateHandle(borrowHandle()) ?? false
  }

  public func isInstanceOf(
    _ constructor: borrowing Self,
    in context: isolated Context = #isolation
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      borrowHandle(),
      constructor: constructor.borrowHandle()
    ) ?? false
  }

  public func isArrayBuffer(in context: isolated Context = #isolation) -> Bool {
    context.driverContextHandle.isArrayBufferHandle(borrowHandle())
  }

  public func isTypedArray(in context: isolated Context = #isolation) -> Bool {
    context.driverContextHandle.typedArrayKindForHandle(borrowHandle()) != nil
  }

  // MARK: Callback-value parameters

  public func setProperty(
    _ key: StaticString,
    to value: borrowing InstantContext.CallbackValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated Context = #isolation
  ) -> Bool {
    context.driverContextHandle.setStaticStringPropertyHandle(
      key,
      on: borrowHandle(),
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func setProperty(
    _ key: borrowing InstantContext.PropertyStringKey,
    to value: borrowing InstantContext.CallbackValue,
    attributes: JSHostMemberAttributes = .none,
    in context: isolated Context = #isolation
  ) -> Bool {
    context.driverContextHandle.setPropertyStringKeyHandle(
      key.borrowHandle(in: context.driverContextHandle),
      on: borrowHandle(),
      to: value.borrowHandle(),
      attributes: attributes
    )
  }

  public func call(
    this thisValue: borrowing InstantContext.CallbackValue,
    arguments: [ValueHandle] = [],
    in context: isolated Context = #isolation
  ) -> JSResult<Context.Value> {
    bridgeSurfaceHandleResult(
      context.driverContextHandle.callFunctionHandle(
        borrowHandle(),
        this: thisValue.borrowHandle(),
        arguments: arguments
      ),
      in: context
    )
  }

  public func isInstanceOf(
    _ constructor: borrowing InstantContext.CallbackValue,
    in context: isolated Context = #isolation
  ) -> Bool {
    context.driverContextHandle.isInstanceOfHandle(
      borrowHandle(),
      constructor: constructor.borrowHandle()
    ) ?? false
  }
}
