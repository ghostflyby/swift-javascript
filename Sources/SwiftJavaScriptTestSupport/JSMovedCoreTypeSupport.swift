import SwiftJavaScript

package final class DummyJSClassInstance: Sendable {
  package init() {}
}

package final class MockExportedJSClassInstance: JSClassValueConvertible, Sendable {
  package typealias Engine = MockEngine
  package typealias ParentClass = JSClass<MockEngine>
  package typealias PropertyNameAccumulator = Never
  package typealias ClassDefinition = JSEngineClassDefinition<
    MockEngine, JSClass<MockEngine>, Never
  >

  package init() {}

  package static var jsClassDefinition:
    JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>
  {
    var definition = JSEngineClassDefinition<MockEngine, JSClass<MockEngine>, Never>()
    definition.className = "ExportedChild"
    definition.parentClass = mockClass("Parent")
    return definition
  }

  package static func tryDecode<E: JSEngine>(
    _ value: borrowing JSValue<E>,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> MockExportedJSClassInstance {
    _ = value
    _ = context
    return MockExportedJSClassInstance()
  }

  @_lifetime(borrow context)
  package static func tryEncode<E: JSEngine>(
    _ value: MockExportedJSClassInstance,
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    _ = value
    return JSValue<E>(undefinedIn: context)
  }

  @_lifetime(borrow context)
  package func toJSValue<E: JSEngine>(in context: borrowing JSInstantContext<E>) -> JSValue<E> {
    MockExportedJSClassInstance.encode(self, in: context)
  }

  @_lifetime(borrow context)
  package func tryEncode<E: JSEngine>(
    in context: borrowing JSInstantContext<E>
  ) throws(JSValueConversionError) -> JSValue<E> {
    try MockExportedJSClassInstance.tryEncode(self, in: context)
  }
}

@_lifetime(immortal)
package func mockUndefinedValue() -> JSValue<MockEngine> {
  JSValue<MockEngine>(
    handleValue: MockValueHandle(rawValue: MockValue(kind: "undefined", payload: "test"))
  )
}

package func mockClass(_ id: String) -> JSClass<MockEngine> {
  JSClass(handleClass: MockClassHandle(rawClass: MockClass(id: id)))
}

@_lifetime(immortal)
package func mockInstantContext() -> JSInstantContext<MockEngine> {
  JSInstantContext(handle: MockContextHandle(rawContext: MockContext(runtimeID: "runtime-token")))
}

@_lifetime(borrow definition, borrow context)
package func readStaticValue<D: JSStaticValueDefinition>(
  _ definition: D,
  in context: borrowing JSInstantContext<D.Engine>,
  from thisValue: borrowing JSValue<D.Engine>
) -> JSResult<JSValue<D.Engine>> {
  definition.propertyValue(in: context, on: thisValue)
}

@_lifetime(borrow definition, borrow context)
package func callStaticFunction<D: JSStaticFunctionDefinition>(
  _ definition: D,
  in context: borrowing JSInstantContext<D.Engine>,
  on thisValue: borrowing JSValue<D.Engine>,
  with arguments: borrowing JSArguments<D.Engine>
) -> JSResult<JSValue<D.Engine>> {
  definition.callResult(in: context, on: thisValue, with: arguments)
}
