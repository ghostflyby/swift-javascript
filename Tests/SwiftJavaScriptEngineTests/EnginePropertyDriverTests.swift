import Testing

@testable import SwiftJavaScript

@Suite
struct EnginePropertyDriverTests {
  @Test(arguments: ScriptEngine.allCases)
  func setGetHasDeletePropertyWithStringKey(_ engine: ScriptEngine) async {
    await engine.run(SetGetHasDeletePropertyWithStringKey.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func setGetHasDeletePropertyWithValueKey(_ engine: ScriptEngine) async {
    await engine.run(SetGetHasDeletePropertyWithValueKey.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func setGetPropertyAtIndex(_ engine: ScriptEngine) async {
    await engine.run(SetGetPropertyAtIndex.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func propertyAttributesAreRespected(_ engine: ScriptEngine) async {
    await engine.run(PropertyAttributesAreRespected.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func propertyNamesReturnOwnEnumerableStringAndIndexKeys(_ engine: ScriptEngine) async {
    await engine.run(PropertyNamesReturnOwnEnumerableStringAndIndexKeys.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func definePropertyAppliesAttributes(_ engine: ScriptEngine) async {
    await engine.run(DefinePropertyAppliesAttributes.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func definePropertyRespectsDontEnumAndDontDelete(_ engine: ScriptEngine) async {
    await engine.run(DefinePropertyRespectsDontEnumAndDontDelete.self)
  }

  @Test(arguments: ScriptEngine.allCases)
  func staticStringPropertyEdgeCases(_ engine: ScriptEngine) async {
    await engine.run(StaticStringPropertyEdgeCases.self)
  }
}

private enum SetGetHasDeletePropertyWithStringKey: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let object = makePersistentObject(in: scope)
      let key: StaticString = "strKey"
      _ = object.setProperty(key, to: scope.makeNumber(3.5), attributes: .none, in: scope)

      let hasBeforeDelete = object.hasProperty(key, in: scope)
      guard let read = valueOrNil(object.getProperty(key, in: scope)) else {
        Issue.record("Expected property read to succeed")
        return
      }
      expectTrue(hasBeforeDelete)
      expectTrue(read.isNumber())

      _ = object.deleteProperty(key, in: scope)
      let hasAfterDelete = object.hasProperty(key, in: scope)
      expectTrue(!hasAfterDelete)
    }
  }
}

private enum SetGetHasDeletePropertyWithValueKey: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let object = makePersistentObject(in: scope)
      let key = scope.makePropertyStringKey("valueKey")
      _ = object.setProperty(
        key, to: scope.persist(scope.makeString("abc")), attributes: .none, in: scope)

      let hasBeforeDelete = object.hasProperty(key, in: scope)
      guard let read = valueOrNil(object.getProperty(key, in: scope)) else {
        Issue.record("Expected property read to succeed")
        return
      }
      expectTrue(hasBeforeDelete)
      expectTrue(read.isString())

      _ = object.deleteProperty(key, in: scope)
      let hasAfterDelete = object.hasProperty(key, in: scope)
      expectTrue(!hasAfterDelete)
    }
  }
}

private enum SetGetPropertyAtIndex: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let object = makePersistentObject(in: scope)
      _ = object.setProperty(
        at: 2, to: scope.persist(scope.makeBoolean(true)), in: scope)
      guard let read = valueOrNil(object.getProperty(at: 2, in: scope)) else {
        Issue.record("Expected index property read to succeed")
        return
      }
      expectTrue(read.isBoolean())
    }
  }
}

private enum PropertyAttributesAreRespected: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let object = makePersistentObject(in: scope)

      _ = object.setProperty(
        "stringLocked", to: scope.makeNumber(11), attributes: .readOnly, in: scope)
      _ = object.setProperty(
        "stringLocked", to: scope.makeNumber(13), attributes: .none, in: scope)
      let stringLockedValue = numberValue(
        object.getProperty("stringLocked", in: scope))
      expectTrue(stringLockedValue == 11)

      _ = object.setProperty(
        "stringHidden", to: scope.makeNumber(17), attributes: .dontEnum, in: scope)
      _ = object.setProperty(
        "stringPinned", to: scope.makeNumber(19), attributes: .dontDelete, in: scope)

      let lockedKey = scope.makePropertyStringKey("locked")
      _ = object.setProperty(
        lockedKey, to: scope.persist(scope.makeNumber(7)),
        attributes: .readOnly, in: scope)
      _ = object.setProperty(
        lockedKey, to: scope.persist(scope.makeNumber(9)),
        attributes: .none, in: scope)
      let lockedValue = numberValue(
        object.getProperty(lockedKey, in: scope))
      expectTrue(lockedValue == 7)

      let hiddenKey = scope.makePropertyStringKey("hidden")
      _ = object.setProperty(
        hiddenKey, to: scope.persist(scope.makeNumber(1)),
        attributes: .dontEnum, in: scope)

      let pinnedKey = scope.makePropertyStringKey("pinned")
      _ = object.setProperty(
        pinnedKey, to: scope.persist(scope.makeNumber(2)),
        attributes: .dontDelete, in: scope)

      scope.setGlobalProperty(object, forKey: "attributeObject", with: .none)
      let hiddenEnumerated = scope.evaluateScript(
        "Object.keys(attributeObject).includes('hidden')"
      )
      let stringHiddenEnumerated = scope.evaluateScript(
        "Object.keys(attributeObject).includes('stringHidden')"
      )
      let pinnedDeleted = scope.evaluateScript("delete attributeObject.pinned")
      let pinnedStillPresent = scope.evaluateScript("'pinned' in attributeObject")
      let stringPinnedDeleted = scope.evaluateScript("delete attributeObject.stringPinned")
      let stringPinnedStillPresent = scope.evaluateScript("'stringPinned' in attributeObject")

      switch consume hiddenEnumerated {
      case .value(let value):
        expectTrue(!value.toBoolean())
      case .exception:
        Issue.record("Expected Object.keys check for hidden value-key property")
      }

      switch consume stringHiddenEnumerated {
      case .value(let value):
        expectTrue(!value.toBoolean())
      case .exception:
        Issue.record("Expected Object.keys check for hidden string-key property")
      }

      switch consume pinnedDeleted {
      case .value(let value):
        expectTrue(!value.toBoolean())
      case .exception:
        Issue.record("Expected delete check for pinned value-key property")
      }

      switch consume pinnedStillPresent {
      case .value(let value):
        expectTrue(value.toBoolean())
      case .exception:
        Issue.record("Expected membership check for pinned value-key property")
      }

      switch consume stringPinnedDeleted {
      case .value(let value):
        expectTrue(!value.toBoolean())
      case .exception:
        Issue.record("Expected delete check for pinned string-key property")
      }

      switch consume stringPinnedStillPresent {
      case .value(let value):
        expectTrue(value.toBoolean())
      case .exception:
        Issue.record("Expected membership check for pinned string-key property")
      }
    }
  }
}

private enum PropertyNamesReturnOwnEnumerableStringAndIndexKeys: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let objectResult = scope.evaluateScript(
        """
        (() => {
          const parent = { inherited: 1 };
          const object = Object.create(parent);
          object.visible = 2;
          object[3] = 3;
          Object.defineProperty(object, 'hidden', { value: 4, enumerable: false });
          object[Symbol('symbolKey')] = 5;
          return object;
        })()
        """
      )

      switch consume objectResult {
      case .value(let object):
        _ = scope.evaluateScript("Object.keys = () => ['patched']")
        let names = object.propertyNames(in: scope)
        expectTrue(names == ["3", "visible"])
      case .exception:
        Issue.record("Expected propertyNames fixture object")
      }
    }
  }
}

private enum DefinePropertyAppliesAttributes: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let object = makePersistentObject(in: scope)
      let key: StaticString = "locked"

      _ = object.setProperty(
        key, to: scope.makeNumber(7), attributes: .readOnly, in: scope)
      guard let stored = valueOrNil(object.getProperty(key, in: scope)) else {
        Issue.record("Expected defineProperty to succeed")
        return
      }
      expectTrue(stored.toNumber() == 7)

      _ = object.setProperty(
        key, to: scope.makeNumber(9), attributes: .none, in: scope)
      guard let storedAfterWrite = valueOrNil(object.getProperty(key, in: scope)) else {
        Issue.record("Expected property read after read-only write")
        return
      }
      expectTrue(storedAfterWrite.toNumber() == 7)
    }
  }
}

private enum DefinePropertyRespectsDontEnumAndDontDelete: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let hiddenKey: StaticString = "hiddenFlag"
      let pinnedKey: StaticString = "pinnedFlag"

      scope.setGlobalProperty(true, forKey: hiddenKey, with: .dontEnum)
      scope.setGlobalProperty(Int32(1), forKey: pinnedKey, with: .dontDelete)

      let hiddenEnumerated = scope.evaluateScript(
        "Object.keys(globalThis).includes('hiddenFlag')"
      )
      let pinnedDeleted = scope.evaluateScript(
        "delete globalThis.pinnedFlag"
      )
      let pinnedStillPresent = scope.evaluateScript(
        "'pinnedFlag' in globalThis"
      )

      switch consume hiddenEnumerated {
      case .value(let value):
        expectTrue(!value.toBoolean())
      case .exception:
        Issue.record("Expected Object.keys check for hiddenFlag")
      }

      switch consume pinnedDeleted {
      case .value(let value):
        expectTrue(!value.toBoolean())
      case .exception:
        Issue.record("Expected delete operator check for pinnedFlag")
      }

      switch consume pinnedStillPresent {
      case .value(let value):
        expectTrue(value.toBoolean())
      case .exception:
        Issue.record("Expected membership check for pinnedFlag")
      }
    }
  }
}

private enum StaticStringPropertyEdgeCases: ScriptEngineAssertion {
  static func run<C: JSContext>(_: C.Type) async {
    let context = C(virtualMachine: C.VirtualMachine())

    await context.withInstantContext { scope in
      let object = makePersistentObject(in: scope)

      // --- value type roundtrips ---
      let numKey: StaticString = "num"
      _ = object.setProperty(
        numKey, to: scope.makeNumber(42.5), attributes: .none, in: scope)
      expectTrue(numberValue(object.getProperty(numKey, in: scope)) == 42.5)
      expectTrue(object.hasProperty(numKey, in: scope))

      let boolKey: StaticString = "flag"
      _ = object.setProperty(
        boolKey, to: scope.makeBoolean(true), attributes: .none, in: scope)
      expectTrue(booleanValue(object.getProperty(boolKey, in: scope)) == true)

      let strKey: StaticString = "greeting"
      _ = object.setProperty(
        strKey, to: scope.makeString("hello"), attributes: .none, in: scope)
      expectTrue(stringValue(object.getProperty(strKey, in: scope)) == "hello")

      // --- surface decoder read via StaticString ---
      let typedKey: StaticString = "pi"
      _ = object.setProperty(
        typedKey, to: scope.makeNumber(3.14), attributes: .none, in: scope)
      guard let piValue = valueOrNil(object.getProperty(typedKey, in: scope)) else {
        Issue.record("Expected pi property read")
        return
      }
      let decoded = try? Double(value: piValue, in: scope)
      expectTrue(decoded == 3.14)

      let typedBoolKey: StaticString = "yes"
      _ = object.setProperty(
        typedBoolKey, to: scope.makeBoolean(true), attributes: .none, in: scope)
      guard let yesValue = valueOrNil(object.getProperty(typedBoolKey, in: scope)) else {
        Issue.record("Expected yes property read")
        return
      }
      let decodedBool = try? Bool(value: yesValue, in: scope)
      expectTrue(decodedBool == true)

      // --- delete + hasProperty ---
      let delKey: StaticString = "temp"
      _ = object.setProperty(
        delKey, to: scope.makeNumber(1), attributes: .none, in: scope)
      expectTrue(object.hasProperty(delKey, in: scope))
      _ = object.deleteProperty(delKey, in: scope)
      expectTrue(!object.hasProperty(delKey, in: scope))

      // --- non-existent key ---
      let missingKey: StaticString = "nope"
      expectTrue(!object.hasProperty(missingKey, in: scope))
      _ = object.deleteProperty(missingKey, in: scope)

      // --- empty StaticString key ---
      let emptyKey: StaticString = ""
      _ = object.setProperty(
        emptyKey, to: scope.makeString("empty-val"), attributes: .none, in: scope)
      expectTrue(object.hasProperty(emptyKey, in: scope))
      expectTrue(stringValue(object.getProperty(emptyKey, in: scope)) == "empty-val")
      _ = object.deleteProperty(emptyKey, in: scope)
      expectTrue(!object.hasProperty(emptyKey, in: scope))

      // --- unicode and special char StaticString key ---
      let uniKey: StaticString = "key_😀"
      _ = object.setProperty(
        uniKey, to: scope.makeString("unicode"), attributes: .none, in: scope)
      expectTrue(object.hasProperty(uniKey, in: scope))
      expectTrue(stringValue(object.getProperty(uniKey, in: scope)) == "unicode")

      let nullCharKey: StaticString = "a\0b"
      _ = object.setProperty(
        nullCharKey, to: scope.makeString("null"), attributes: .none, in: scope)
      expectTrue(object.hasProperty(nullCharKey, in: scope))
      expectTrue(stringValue(object.getProperty(nullCharKey, in: scope)) == "null")
      _ = object.deleteProperty(nullCharKey, in: scope)
      expectTrue(!object.hasProperty(nullCharKey, in: scope))
    }
  }
}

// MARK: - Shared value helpers
//
// The whole surface property API is value-level; the only helper left is the
// persistent object every property test writes to. The raw value-key driver
// path (a JS string value used as the property key) has no public value-level
// equivalent, so that coverage lives in the two concrete engine targets.

private func makePersistentObject<C: JSInstantContext & ~Copyable>(
  in context: borrowing C
) -> C.Value {
  guard let object = valueOrNil(context.makeObject()) else {
    preconditionFailure("makeObject failed")
  }
  return context.persist(object)
}

// MARK: - Result readers

private func numberValue<V: JSValue & ~Copyable>(_ result: consuming JSResult<V>) -> Double? {
  guard let value = valueOrNil(result) else { return nil }
  return value.toNumber()
}

private func booleanValue<V: JSValue & ~Copyable>(_ result: consuming JSResult<V>) -> Bool? {
  guard let value = valueOrNil(result) else { return nil }
  return value.toBoolean()
}

private func stringValue<V: JSValue & ~Copyable>(_ result: consuming JSResult<V>) -> String? {
  guard let value = valueOrNil(result) else { return nil }
  return value.toString()
}

/// `#expect` rewrites its expression and cannot capture the non-copyable
/// surface value views; binding the boolean first keeps the macro on a plain
/// `Bool` while the test still uses the protocol-level APIs.
private func expectTrue(
  _ condition: Bool,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  #expect(condition, sourceLocation: sourceLocation)
}

/// Take the value arm of a non-copyable `JSResult` without touching the
/// exception payload.
private func valueOrNil<V: ~Copyable>(_ result: consuming JSResult<V>) -> V? {
  switch consume result {
  case .value(let value):
    return value
  case .exception:
    return nil
  }
}
