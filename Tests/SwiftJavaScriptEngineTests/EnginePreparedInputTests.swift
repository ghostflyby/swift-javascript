import Testing

@testable import SwiftJavaScript

@Suite
struct EnginePreparedInputTests {
  @Test(arguments: ScriptEngine.allCases)
  func propertyStringKeyCanBeReused(_ engine: ScriptEngine) async {
    await engine.run(PropertyStringKeyCanBeReused.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func propertyStringKeyPreservesUTF16AndEmbeddedNUL(_ engine: ScriptEngine) async {
    await engine.run(PropertyStringKeyPreservesUTF16AndEmbeddedNUL.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func propertyStringKeyCanCreateStringValue(_ engine: ScriptEngine) async {
    await engine.run(PropertyStringKeyCanCreateStringValue.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func preparedScriptCanBeReused(_ engine: ScriptEngine) async {
    await engine.run(PreparedScriptCanBeReused.self)
  }

  /// The surface inputs own their engine representation and can outlive the
  /// synchronous window that created them: both are minted in one window,
  /// carried across the actor hop, and used in a later window.
  @Test(arguments: ScriptEngine.allCases)
  func surfaceInputsSurviveTheCreatingWindow(_ engine: ScriptEngine) async {
    await engine.run(SurfaceInputsSurviveTheCreatingWindow.self)
  }
}

private enum PropertyStringKeyCanBeReused: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { context in
      let object = context.makePersistentObject()
      let key = context.makePropertyStringKey("count")

      let one = context.persist(context.makeNumber(1))
      let two = context.persist(context.makeNumber(2))
      _ = object.setProperty(key, to: one, attributes: .none, in: context)
      let first = object.propertyNumber(key, in: context)
      _ = object.setProperty(key, to: two, attributes: .none, in: context)
      let second = object.propertyNumber(key, in: context)
      let hasKey = object.hasProperty(key, in: context)

      #expect(first == 1)
      #expect(second == 2)
      #expect(hasKey)
    }
  }
}

private enum PropertyStringKeyPreservesUTF16AndEmbeddedNUL: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { context in
      let object = context.makePersistentObject()
      let keyText = "emoji_😀_\u{0}_tail"
      let key = context.makePropertyStringKey(keyText)

      let ok = context.persist(context.makeString("ok"))
      _ = object.setProperty(key, to: ok, attributes: .none, in: context)

      #expect(object.propertyString(key, in: context) == "ok")
      let sameKey = context.makePropertyStringKey(keyText)
      #expect(object.propertyString(sameKey, in: context) == "ok")
    }
  }
}

private enum PropertyStringKeyCanCreateStringValue: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { context in
      let text = "key_😀_\u{0}_tail"
      let key = context.makePropertyStringKey(text)
      let value = context.makeString(from: key)

      #expect(value.toString() == text)
    }
  }
}

private enum PreparedScriptCanBeReused: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    await context.withInstantContext { context in
      let script = context.prepareScript(
        "globalThis.__preparedCount = (globalThis.__preparedCount ?? 0) + 1")

      _ = context.evaluateScript(script, sourceURL: "inline://prepared.js", startingLineNumber: 3)
      _ = context.evaluateScript(script, sourceURL: "inline://prepared.js", startingLineNumber: 3)

      let value = context.getGlobalProperty(forKey: "__preparedCount").toNumber()
      #expect(value == 2)
    }
  }
}
extension JSValueScope where Self: ~Copyable {
  fileprivate func makePersistentObject() -> Value {
    let result = makeObject()
    switch consume result {
    case .value(let object):
      return persist(object)
    case .exception:
      preconditionFailure("makeObject failed")
    }
  }
}

private enum SurfaceInputsSurviveTheCreatingWindow: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = await makeContext(C.self)

    // Minted inside one synchronous window; the wrappers own the context
    // reference that keeps them usable outside it.
    let key = await context.withInstantContext { scope in
      scope.makePropertyStringKey("survivor")
    }
    let script = await context.withInstantContext { scope in
      scope.prepareScript("40 + 2")
    }

    let keyText = await context.withInstantContext { scope in
      scope.makeString(from: key).toString()
    }
    #expect(keyText == "survivor")

    let evaluated = await context.withInstantContext { scope -> Double in
      let result = scope.evaluateScript(
        script,
        sourceURL: "inline://survivor.js",
        startingLineNumber: 1
      )
      switch consume result {
      case .value(let value):
        return value.toNumber()
      case .exception:
        return -1
      }
    }
    #expect(evaluated == 42)
  }
}

extension JSValue where Self: ~Copyable {
  fileprivate func propertyString(
    _ key: borrowing Context.PropertyStringKey,
    in context: borrowing InstantContext
  ) -> String {
    let result = getProperty(key, in: context)
    switch consume result {
    case .value(let value):
      return value.toString()
    case .exception:
      return "<exception>"
    }
  }

  fileprivate func propertyNumber(
    _ key: borrowing Context.PropertyStringKey,
    in context: borrowing InstantContext
  ) -> Double {
    let result = getProperty(key, in: context)
    switch consume result {
    case .value(let value):
      return value.toNumber()
    case .exception:
      return .nan
    }
  }
}
