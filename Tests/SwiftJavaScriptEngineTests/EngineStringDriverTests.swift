import SwiftJavaScript
import Testing

@Suite
struct EngineStringDriverTests {
  @Test(arguments: ScriptEngine.allCases)
  func stringInitFromJSStringHandle(_ engine: ScriptEngine) async {
    await engine.run(StringInitFromJSStringHandle.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func jsStringManagedBasics(_ engine: ScriptEngine) async {
    await engine.run(JSStringManagedBasics.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func jsStringManagedEmpty(_ engine: ScriptEngine) async {
    await engine.run(JSStringManagedEmpty.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func jsStringGroupInitAndEquality(_ engine: ScriptEngine) async {
    await engine.run(JSStringGroupInitAndEquality.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func jsStringValueInitsAndCaching(_ engine: ScriptEngine) async {
    await engine.run(JSStringValueInitsAndCaching.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func jsStringPreservesUTF16Content(_ engine: ScriptEngine) async {
    await engine.run(JSStringPreservesUTF16Content.self)
  }
}

private enum StringInitFromJSStringHandle: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let managed = JSStringManaged<E>("hello")
    let swiftString = String(jsStringHandle: managed.jsStringHandle, engine: E.self)

    #expect(swiftString == "hello")
  }
}

private enum JSStringManagedBasics: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let value = JSStringManaged<E>("abc")

    #expect(value.string == "abc")
    #expect(value.cached == "abc")
  }
}

private enum JSStringManagedEmpty: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    #expect(JSStringManaged<E>.empty.string == "")
  }
}

private enum JSStringGroupInitAndEquality: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let managed = JSStringManaged<E>("group")
    let grouped = JSStringManaged<E>(group: managed)

    let eq1 = grouped == managed
    let ne = grouped != JSStringManaged<E>("other")

    #expect(eq1)
    #expect(ne)
  }
}

private enum JSStringValueInitsAndCaching: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let base = JSStringValue<E>("cache")
    let noCache = JSStringValue<E>(base, caching: false)
    let withCache = JSStringValue<E>(base, caching: true)
    let fromManaged = JSStringValue<E>(JSStringManaged<E>("m"), caching: true)

    let baseCached = base.cached
    let noCacheString = noCache.string
    let withCacheCached = withCache.cached
    let fromManagedCached = fromManaged.cached

    #expect(baseCached == "cache")
    #expect(noCacheString == "cache")
    #expect(withCacheCached == "cache")
    #expect(fromManagedCached == "m")
  }
}

private enum JSStringPreservesUTF16Content: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let source = "emoji: 😀 cafe: cafe\u{301}"
    let managed = JSStringManaged<E>(source)
    let value = JSStringValue<E>(managed, caching: false)

    #expect(managed.string == source)
    #expect(value.string == source)
  }
}
