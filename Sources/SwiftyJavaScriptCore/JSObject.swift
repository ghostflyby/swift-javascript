extension JSValue {
  public func setProperty(
    _ value: borrowing JSValue,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) {
    setProperty(value, forKey: key.string, with: attributes, in: context)
  }

  public func setProperty(
    _ value: borrowing JSValue,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) {
    setProperty(value, forKey: key.string, with: attributes, in: context)
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) where Val: JSValueEncodable, Val: ~Copyable {
    setProperty(value, forKey: key.string, with: attributes, in: context)
  }

  public func setProperty<Val>(
    _ value: borrowing Val,
    forKey key: borrowing some JSString,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) where Val: JSValueEncodable, Val: ~Copyable {
    setProperty(value, forKey: key.string, with: attributes, in: context)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing some JSString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: borrowing JSInstantContext
  ) {
    setProperty(value, forKey: key.string, using: converter, with: attributes, in: context)
  }

  public func setProperty<C: JSValueEncoder>(
    _ value: C.SwiftType,
    forKey key: borrowing some JSString,
    using converter: C.Type,
    with attributes: JSPropertyAttributes = .none,
    in context: isolated JSContext = #isolation
  ) {
    setProperty(value, forKey: key.string, using: converter, with: attributes, in: context)
  }

  public func getProperty(
    forKey key: borrowing some JSString,
    in context: borrowing JSInstantContext
  ) -> JSValue {
    getProperty(forKey: key.string, in: context)
  }

  public func getProperty(
    forKey key: borrowing some JSString,
    in context: isolated JSContext = #isolation
  ) -> JSValue {
    getProperty(forKey: key.string, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing some JSString,
    using converter: C.Type,
    in context: borrowing JSInstantContext
  ) -> C.SwiftType {
    getProperty(forKey: key.string, using: converter, in: context)
  }

  public func getProperty<C: JSValueDecoder>(
    forKey key: borrowing some JSString,
    using converter: C.Type,
    in context: isolated JSContext = #isolation
  ) -> C.SwiftType {
    getProperty(forKey: key.string, using: converter, in: context)
  }

  public func deleteProperty(
    forKey key: borrowing some JSString,
    in context: borrowing JSInstantContext
  ) {
    deleteProperty(forKey: key.string, in: context)
  }

  public func deleteProperty(
    forKey key: borrowing some JSString,
    in context: isolated JSContext = #isolation
  ) {
    deleteProperty(forKey: key.string, in: context)
  }

  public func hasProperty(
    _ key: borrowing some JSString,
    in context: borrowing JSInstantContext
  ) -> Bool {
    hasProperty(key.string, in: context)
  }

  public func hasProperty(
    _ key: borrowing some JSString,
    in context: isolated JSContext = #isolation
  ) -> Bool {
    hasProperty(key.string, in: context)
  }
}
