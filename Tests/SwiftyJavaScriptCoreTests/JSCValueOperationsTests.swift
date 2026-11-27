import JavaScriptCore
import Testing

@testable import SwiftJavaScript
@testable import SwiftyJavaScriptCore

// MARK: - JSCValue property/object/invocation surface (S5)
//
// The synchronous surface is addressed through the S3 shell scope; the
// `#isolation` form is the core protocol extension and is exercised through a
// function isolated to the context actor. Every result handle is adopted by
// the receiving arena exactly once, so the scope drain settles each reference.

private func makeContext() -> (JSContextGroupRef, JSGlobalContextRef) {
  let runtime = JSContextGroupCreate()!
  guard let context = javaScriptCoreMakeBorrowedContextHandleFromRuntime(in: runtime) else {
    preconditionFailure("JSCEngine could not create a context handle")
  }
  return (runtime, context)
}

private func adoptObject(in scope: borrowing JSCInstantContext) -> JSCValue {
  let context = scope.contextRef
  guard let result = javaScriptCoreMakeObjectResultHandle(context) else {
    preconditionFailure("JSCEngine could not create an object")
  }
  switch consume result {
  case .value(let handle):
    return scope.adoptCreatedHandle(handle)
  case .exception(let handle):

    preconditionFailure("JSCEngine object creation returned an exception")
  }
}

private func adoptEvaluated(
  _ source: String,
  in scope: borrowing JSCInstantContext
) -> JSCValue {
  let context = scope.contextRef
  guard let script = javaScriptCoreMakePreparedScriptHandle(source, in: context),
    let result = javaScriptCoreEvaluatePreparedScriptResultHandle(
      script,
      context,
      sourceURL: nil,
      startingLineNumber: 1
    )
  else {
    preconditionFailure("JSCEngine could not evaluate \(source)")
  }
  switch consume result {
  case .value(let handle):
    return scope.adoptCreatedHandle(handle)
  case .exception(let handle):

    preconditionFailure("JSCEngine evaluation of \(source) threw")
  }
}

private func adoptString(
  _ value: String,
  in scope: borrowing JSCInstantContext
) -> JSCValue {
  guard let handle = javaScriptCoreMakeStringValueHandle(value, scope.contextRef) else {
    preconditionFailure("JSCEngine could not create a string")
  }
  return scope.adoptCreatedHandle(handle)
}

/// Collapse a noncopyable result into a Copyable description before any
/// assertion reads it.
private func describe(_ result: consuming JSResult<JSCValue>) -> String {
  switch consume result {
  case .value(let value):
    return value.toString()
  case .exception:
    return "<exception>"
  }
}

private func value(_ result: consuming JSResult<JSCValue>) -> JSCValue {
  switch consume result {
  case .value(let value):
    return value
  case .exception:
    preconditionFailure("expected a value result")
  }
}

// MARK: - `#isolation` callback (iso2 shape)

/// Isolated to the context actor, so `value.getProperty("name")` resolves to
/// the core same-name overload whose `in context` defaults to `#isolation`.
/// The window is opened on the actor itself, so nothing but the context handle
/// crosses isolation.
private func isolatedNameRead(
  _ contextRef: JSGlobalContextRef,
  on _: isolated JSCContext
) -> String {
  let scope = JSCInstantContext(contextRef: contextRef)
  let object = adoptObject(in: scope)
  let text = adoptString("seven", in: scope)
  _ = object.setProperty("name", to: text, attributes: .none, in: scope)
  switch object.getProperty("name") {
  case .value(let result):
    return result.toString()
  case .exception:
    return "<exception>"
  }
}

@Suite
struct JSCValueOperationsTests {
  @Test
  func readsWritesAndRemovesStaticAndKeyProperties() {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)
      let object = adoptObject(in: scope)
      let text = adoptString("seven", in: scope)

      let didSet = object.setProperty("name", to: text, attributes: .none, in: scope)
      let hasName = object.hasProperty("name", in: scope)
      let hasAbsent = object.hasProperty("absent", in: scope)
      let readText = describe(object.getProperty("name", in: scope))
      let absentText = describe(object.getProperty("absent", in: scope))
      let names = object.propertyNames(in: scope)
      #expect(didSet)
      #expect(hasName)
      #expect(!hasAbsent)
      #expect(readText == "seven")
      #expect(absentText == "undefined")
      #expect(names == ["name"])

      guard let keyHandle = javaScriptCoreMakePropertyStringKeyHandle("count", in: context) else {
        Issue.record("JSCEngine could not make a property key")
        return
      }
      let number = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(3, context)!)
      do {
        let key = JSCPropertyStringKey(
          stringRef: keyHandle,
          contextRef: context,
          context: nil
        )
        let keyDidSet = object.setProperty(
          key,
          to: number,
          attributes: .none,
          in: scope
        )
        let keyHas = object.hasProperty(key, in: scope)
        let keyRead = describe(object.getProperty(key, in: scope))
        let keyDeleted = object.deleteProperty(key, in: scope)
        let keyHasAfterDelete = object.hasProperty(key, in: scope)
        #expect(keyDidSet)
        #expect(keyHas)
        #expect(keyRead == "3")
        #expect(keyDeleted)
        #expect(!keyHasAfterDelete)
      }
      // Ownership of `keyHandle` moved into `key`; the wrapper releases it.

      let deleted = object.deleteProperty("name", in: scope)
      let hasAfterDelete = object.hasProperty("name", in: scope)
      #expect(deleted)
      #expect(!hasAfterDelete)
      #expect(object.propertyNames(in: scope).isEmpty)

      // Callback-window value views only carry an identity; the direct-value
      // surface accepts them by borrowing that identity.
      let callbackValue = JSCValue(
        ref: text.ref,
        contextRef: context
      )
      let callbackDidSet = object.setProperty(
        "alias",
        to: callbackValue,
        attributes: .none,
        in: scope
      )
      let aliasText = describe(object.getProperty("alias", in: scope))
      #expect(callbackDidSet)
      #expect(aliasText == "seven")

      #expect(scope.contextRef == context)
    }
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }

  @Test
  func callsConstructsInvokesMethodsAndClassifiesObjects() {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)
      let text = adoptString("seven", in: scope)

      let function = adoptEvaluated("(function () { return 42; })", in: scope)
      let callText = describe(function.call(arguments: [], in: scope))
      #expect(callText == "42")

      let thisFunction = adoptEvaluated("(function () { return this.name; })", in: scope)
      let receiver = adoptObject(in: scope)
      _ = receiver.setProperty("name", to: text, attributes: .none, in: scope)
      let thisText = describe(thisFunction.call(this: receiver, arguments: [], in: scope))
      #expect(thisText == "seven")

      let constructor = adoptEvaluated("(function () { this.value = 11; })", in: scope)
      let instance = value(constructor.construct(arguments: [], in: scope))
      let instanceValue = describe(instance.getProperty("value", in: scope))
      #expect(instanceValue == "11")

      let methodObject = adoptEvaluated(
        "({ value: 21, double: function () { return this.value * 2; }, plus: function (n) { return this.value + n; } })",
        in: scope
      )
      let methodText = describe(methodObject.invokeMethod("double", arguments: [], in: scope))
      let argument = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(21, context)!)
      let withArgumentText = describe(
        methodObject.invokeMethod("plus", arguments: [argument.asCallArgument()], in: scope)
      )
      #expect(methodText == "42")
      #expect(withArgumentText == "42")

      let array = adoptEvaluated("[1, 2, 3]", in: scope)
      let date = adoptEvaluated("new Date()", in: scope)
      let arrayBuffer = adoptEvaluated("new ArrayBuffer(8)", in: scope)
      let typedArray = adoptEvaluated("new Uint8Array(8)", in: scope)
      let arrayIsArray = array.isArray(in: scope)
      let methodIsArray = methodObject.isArray(in: scope)
      let dateIsDate = date.isDate(in: scope)
      let methodIsDate = methodObject.isDate(in: scope)
      let instanceOfConstructor = instance.isInstanceOf(constructor, in: scope)
      let instanceOfFunction = instance.isInstanceOf(function, in: scope)
      let bufferIsArrayBuffer = arrayBuffer.isArrayBuffer(in: scope)
      let typedIsTypedArray = typedArray.isTypedArray(in: scope)
      let typedIsArrayBuffer = typedArray.isArrayBuffer(in: scope)
      let arrayIsTypedArray = array.isTypedArray(in: scope)
      #expect(arrayIsArray)
      #expect(!methodIsArray)
      #expect(dateIsDate)
      #expect(!methodIsDate)
      #expect(instanceOfConstructor)
      #expect(!instanceOfFunction)
      #expect(bufferIsArrayBuffer)
      #expect(typedIsTypedArray)
      #expect(!typedIsArrayBuffer)
      #expect(!arrayIsTypedArray)

      let number = scope.adoptCreatedHandle(javaScriptCoreMakeNumberValueHandle(7, context)!)
      let boxed = value(number.toObject(in: scope))
      let boxedIsObject = boxed.isObject()
      #expect(boxedIsObject)

      let numberText = adoptString("7", in: scope)
      let loose = number.looselyEquals(numberText)
      let strict = number.strictlyEquals(numberText)
      let strictSame = number.strictlyEquals(number)
      #expect(loose)
      #expect(!strict)
      #expect(strictSame)

      // The callback-value parameter overloads borrow the same identities.
      let receiverShell = JSCValue(
        ref: receiver.ref,
        contextRef: context
      )
      let callbackThisText = describe(
        thisFunction.call(this: receiverShell, arguments: [], in: scope)
      )
      #expect(callbackThisText == "seven")

      let constructorShell = JSCValue(
        ref: constructor.ref,
        contextRef: context
      )
      let callbackInstanceOf = instance.isInstanceOf(constructorShell, in: scope)
      #expect(callbackInstanceOf)

      #expect(scope.contextRef == context)
    }
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }

  @Test
  func propertyExceptionAdoptsTheThrownValue() {
    let (runtime, context) = makeContext()
    do {
      let scope = JSCInstantContext(contextRef: context)
      let throwing = adoptEvaluated(
        "({ get boom() { throw new Error('kaboom'); } })",
        in: scope
      )

      let message: String
      switch throwing.getProperty("boom", in: scope) {
      case .value:
        Issue.record("expected a property exception")
        message = ""
      case .exception(let exception):
        message = exception.toString()
      }
      #expect(message.contains("kaboom"))
      // The exception value was adopted, so later reads in the same window
      // still work and the scope drains cleanly.
      let names = throwing.propertyNames(in: scope)
      #expect(names == ["boom"])
      #expect(scope.contextRef == context)
    }
    JSGlobalContextRelease(context)
    JSContextGroupRelease(runtime)
  }

  @Test
  func readsPropertyThroughTheIsolationDefaultOverload() async {
    // The `in:` default reads `#isolation`, so the *opened window* and the
    // actor must be the same context: use the concrete context's own handle.
    let context = await JSCContext(.nonblocking)
    let isolatedText = await isolatedNameRead(context.contextRef, on: context)
    #expect(isolatedText == "seven")
  }
}
