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
}

private enum PropertyStringKeyCanBeReused: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = context.makePersistentObject()
      let key = context.makePropertyStringKey("count")

      object.setProperty(1, forKey: key, in: context)
      let first = object.getProperty(forKey: key, in: context).toInt32(in: context)
      object.setProperty(2, forKey: key, in: context)
      let second = object.getProperty(forKey: key, in: context).toInt32(in: context)
      let hasKey = object.hasProperty(key, in: context)

      #expect(first == 1)
      #expect(second == 2)
      #expect(hasKey)
    }
  }
}

private enum PropertyStringKeyPreservesUTF16AndEmbeddedNUL: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = context.makePersistentObject()
      let keyText = "emoji_😀_\u{0}_tail"
      let key = context.makePropertyStringKey(keyText)

      object.setProperty("ok", forKey: key, in: context)

      #expect(object.getProperty(forKey: key, in: context).toString(in: context) == "ok")
      let sameKey = context.makePropertyStringKey(keyText)
      #expect(object.getProperty(forKey: sameKey, in: context).toString(in: context) == "ok")
    }
  }
}

private enum PropertyStringKeyCanCreateStringValue: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let text = "key_😀_\u{0}_tail"
      let key = context.makePropertyStringKey(text)
      let value = context.makeString(from: key)
      let initialized = JSValue(string: key, in: context)

      #expect(value.toString() == text)
      #expect(initialized.toString(in: context) == text)
    }
  }
}

private enum PreparedScriptCanBeReused: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let script = context.prepareScript(
        "globalThis.__preparedCount = (globalThis.__preparedCount ?? 0) + 1")

      _ = context.evaluateScript(script, sourceURL: "inline://prepared.js", startingLineNumber: 3)
      _ = context.evaluateScript(script, sourceURL: "inline://prepared.js", startingLineNumber: 3)

      let value = context.getGlobalProperty(forKey: "__preparedCount").toInt32(in: context)
      #expect(value == 2)
    }
  }
}
extension JSInstantContext {
  fileprivate func makePersistentObject() -> JSValue<E> {
    let result = makeObject()
    guard case .value(let cb) = result else { preconditionFailure("makeObject failed") }
    return persist(cb)
  }
}
