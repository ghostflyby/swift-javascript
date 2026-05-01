import SwiftJavaScript
import Testing

@Suite
struct EnginePreparedInputTests {
  @Test(arguments: ScriptEngine.allCases)
  func propertyKeyCanBeReused(_ engine: ScriptEngine) async {
    await engine.run(PropertyKeyCanBeReused.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func propertyKeyPreservesUTF16AndEmbeddedNUL(_ engine: ScriptEngine) async {
    await engine.run(PropertyKeyPreservesUTF16AndEmbeddedNUL.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func preparedScriptCanBeReused(_ engine: ScriptEngine) async {
    await engine.run(PreparedScriptCanBeReused.self)
  }
}

private enum PropertyKeyCanBeReused: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = context.makeObject()
      let key = context.makePropertyKey("count")

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

private enum PropertyKeyPreservesUTF16AndEmbeddedNUL: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = context.makeObject()
      let keyText = "emoji_😀_\u{0}_tail"
      let key = context.makePropertyKey(keyText)

      object.setProperty("ok", forKey: key, in: context)

      #expect(object.getProperty(forKey: key, in: context).toString(in: context) == "ok")
      #expect(object.getProperty(forKey: keyText, in: context).toString(in: context) == "ok")
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
