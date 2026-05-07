import SwiftJavaScript
import Testing

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
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = context.makeObject()
      let key: StaticString = "strKey"
      object.setProperty(3.5, forKey: key, in: context)

      let hasBeforeDelete = object.hasProperty(key, in: context)
      let readIsNumber = object.getProperty(forKey: key, in: context).isNumber(in: context)
      #expect(hasBeforeDelete)
      #expect(readIsNumber)

      object.deleteProperty(forKey: key, in: context)
      let hasAfterDelete = object.hasProperty(key, in: context)
      #expect(!hasAfterDelete)
    }
  }
}

private enum SetGetHasDeletePropertyWithValueKey: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = context.makeObject()
      let key = JSValue(string: "valueKey", in: context)
      object.setProperty("abc", forKey: key, in: context)

      let hasBeforeDelete = object.hasProperty(key, in: context)
      let readIsString = object.getProperty(forKey: key, in: context).isString(in: context)
      #expect(hasBeforeDelete)
      #expect(readIsString)

      object.deleteProperty(forKey: key, in: context)
      let hasAfterDelete = object.hasProperty(key, in: context)
      #expect(!hasAfterDelete)
    }
  }
}

private enum SetGetPropertyAtIndex: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = context.makeObject()
      object.setProperty(true, at: 2, in: context)
      let readIsBoolean = object.getProperty(at: 2, in: context).isBoolean(in: context)
      #expect(readIsBoolean)
    }
  }
}

private enum PropertyAttributesAreRespected: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = JSValue(objectIn: context)

      object.setProperty(11, forKey: "stringLocked", with: [.readOnly], in: context)
      object.setProperty(13, forKey: "stringLocked", in: context)
      let stringLockedValue = object.getProperty(forKey: "stringLocked", in: context)
        .toInt32(in: context)
      #expect(stringLockedValue == 11)

      object.setProperty(17, forKey: "stringHidden", with: [.dontEnum], in: context)
      object.setProperty(19, forKey: "stringPinned", with: [.dontDelete], in: context)

      let lockedKey = JSValue(string: "locked", in: context)
      object.setProperty(7, forKey: lockedKey, with: [.readOnly], in: context)
      object.setProperty(9, forKey: lockedKey, in: context)
      let lockedValue = object.getProperty(forKey: lockedKey, in: context).toInt32(in: context)
      #expect(lockedValue == 7)

      let hiddenKey = JSValue(string: "hidden", in: context)
      object.setProperty(1, forKey: hiddenKey, with: [.dontEnum], in: context)

      let pinnedKey = JSValue(string: "pinned", in: context)
      object.setProperty(2, forKey: pinnedKey, with: [.dontDelete], in: context)

      context.withGlobalObject { global in
        global.setProperty(object, forKey: "attributeObject", in: context)
      }
      let hiddenEnumerated = context.evaluateScript(
        "Object.keys(attributeObject).includes('hidden')"
      )
      let stringHiddenEnumerated = context.evaluateScript(
        "Object.keys(attributeObject).includes('stringHidden')"
      )
      let pinnedDeleted = context.evaluateScript("delete attributeObject.pinned")
      let pinnedStillPresent = context.evaluateScript("'pinned' in attributeObject")
      let stringPinnedDeleted = context.evaluateScript("delete attributeObject.stringPinned")
      let stringPinnedStillPresent = context.evaluateScript("'stringPinned' in attributeObject")

      switch consume hiddenEnumerated {
      case .value(let value):
        let isHiddenEnumerated = value.toBool(in: context)
        #expect(!isHiddenEnumerated)
      case .exception:
        Issue.record("Expected Object.keys check for hidden value-key property")
      }

      switch consume stringHiddenEnumerated {
      case .value(let value):
        let isHiddenEnumerated = value.toBool(in: context)
        #expect(!isHiddenEnumerated)
      case .exception:
        Issue.record("Expected Object.keys check for hidden string-key property")
      }

      switch consume pinnedDeleted {
      case .value(let value):
        let didDeletePinned = value.toBool(in: context)
        #expect(!didDeletePinned)
      case .exception:
        Issue.record("Expected delete check for pinned value-key property")
      }

      switch consume pinnedStillPresent {
      case .value(let value):
        let isPinnedStillPresent = value.toBool(in: context)
        #expect(isPinnedStillPresent)
      case .exception:
        Issue.record("Expected membership check for pinned value-key property")
      }

      switch consume stringPinnedDeleted {
      case .value(let value):
        let didDeletePinned = value.toBool(in: context)
        #expect(!didDeletePinned)
      case .exception:
        Issue.record("Expected delete check for pinned string-key property")
      }

      switch consume stringPinnedStillPresent {
      case .value(let value):
        let isPinnedStillPresent = value.toBool(in: context)
        #expect(isPinnedStillPresent)
      case .exception:
        Issue.record("Expected membership check for pinned string-key property")
      }
    }
  }
}

private enum PropertyNamesReturnOwnEnumerableStringAndIndexKeys: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let objectResult = context.evaluateScript(
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
        _ = context.evaluateScript("Object.keys = () => ['patched']")
        let names =
          E.propertyNamesForHandle(
            on: object.borrowHandle(),
            in: context.driverContextHandle
          ) ?? []
        #expect(names == ["3", "visible"])
      case .exception:
        Issue.record("Expected propertyNames fixture object")
      }
    }
  }
}

private enum DefinePropertyAppliesAttributes: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = JSValue(objectIn: context)
      let key: StaticString = "locked"

      let defineResult = object.defineProperty(7, forKey: key, with: [.readOnly], in: context)
      switch consume defineResult {
      case .value(let stored):
        #expect(stored.toInt32(in: context) == 7)
      case .exception:
        Issue.record("Expected defineProperty to succeed")
      }

      object.setProperty(9, forKey: key, in: context)
      let stored = object.getProperty(forKey: key, in: context)
      #expect(stored.toInt32(in: context) == 7)
    }
  }
}

private enum DefinePropertyRespectsDontEnumAndDontDelete: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let hiddenKey: StaticString = "hiddenFlag"
      let pinnedKey: StaticString = "pinnedFlag"

      context.withGlobalObject { global in
        _ = global.defineProperty(true, forKey: hiddenKey, with: [.dontEnum], in: context)
        _ = global.defineProperty(1, forKey: pinnedKey, with: [.dontDelete], in: context)
      }

      let hiddenEnumerated = context.evaluateScript(
        "Object.keys(globalThis).includes('hiddenFlag')"
      )
      let pinnedDeleted = context.evaluateScript(
        "delete globalThis.pinnedFlag"
      )
      let pinnedStillPresent = context.evaluateScript(
        "'pinnedFlag' in globalThis"
      )

      switch consume hiddenEnumerated {
      case .value(let value):
        let isEnumerated = value.toBool(in: context)
        #expect(!isEnumerated)
      case .exception:
        Issue.record("Expected Object.keys check for hiddenFlag")
      }

      switch consume pinnedDeleted {
      case .value(let value):
        let didDelete = value.toBool(in: context)
        #expect(!didDelete)
      case .exception:
        Issue.record("Expected delete operator check for pinnedFlag")
      }

      switch consume pinnedStillPresent {
      case .value(let value):
        let stillPresent = value.toBool(in: context)
        #expect(stillPresent)
      case .exception:
        Issue.record("Expected membership check for pinnedFlag")
      }
    }
  }
}

private enum StaticStringPropertyEdgeCases: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = context.makeObject()

      // --- value type roundtrips ---
      let numKey: StaticString = "num"
      object.setProperty(42.5, forKey: numKey, in: context)
      let numVal = object.getProperty(forKey: numKey, in: context).toDouble(in: context)
      #expect(numVal == 42.5)
      let hasNum = object.hasProperty(numKey, in: context)
      #expect(hasNum)

      let boolKey: StaticString = "flag"
      object.setProperty(true, forKey: boolKey, in: context)
      let boolVal = object.getProperty(forKey: boolKey, in: context).toBool(in: context)
      #expect(boolVal)

      let strKey: StaticString = "greeting"
      object.setProperty("hello", forKey: strKey, in: context)
      let strVal = object.getProperty(forKey: strKey, in: context).toString(in: context)
      #expect(strVal == "hello")

      // --- typed converter read via StaticString ---
      let typedKey: StaticString = "pi"
      object.setProperty(3.14, forKey: typedKey, in: context)
      let decoded: Double = object.getProperty(forKey: typedKey, using: JSDefaultConverter<Double>.self, in: context)
      #expect(decoded == 3.14)

      let typedBoolKey: StaticString = "yes"
      object.setProperty(true, forKey: typedBoolKey, in: context)
      let decodedBool: Bool = object.getProperty(forKey: typedBoolKey, using: JSDefaultConverter<Bool>.self, in: context)
      #expect(decodedBool)

      // --- delete + hasProperty ---
      let delKey: StaticString = "temp"
      object.setProperty(1, forKey: delKey, in: context)
      let hasDel = object.hasProperty(delKey, in: context)
      #expect(hasDel)
      object.deleteProperty(forKey: delKey, in: context)
      let hasDelAfter = object.hasProperty(delKey, in: context)
      #expect(!hasDelAfter)

      // --- non-existent key ---
      let missingKey: StaticString = "nope"
      let hasMissing = object.hasProperty(missingKey, in: context)
      #expect(!hasMissing)
      object.deleteProperty(forKey: missingKey, in: context)

      // --- empty StaticString key ---
      let emptyKey: StaticString = ""
      object.setProperty("empty-val", forKey: emptyKey, in: context)
      let hasEmpty = object.hasProperty(emptyKey, in: context)
      #expect(hasEmpty)
      let emptyVal = object.getProperty(forKey: emptyKey, in: context).toString(in: context)
      #expect(emptyVal == "empty-val")
      object.deleteProperty(forKey: emptyKey, in: context)
      let hasEmptyAfter = object.hasProperty(emptyKey, in: context)
      #expect(!hasEmptyAfter)

      // --- unicode and special char StaticString key ---
      let uniKey: StaticString = "key_😀"
      object.setProperty("unicode", forKey: uniKey, in: context)
      let hasUni = object.hasProperty(uniKey, in: context)
      #expect(hasUni)
      let uniVal = object.getProperty(forKey: uniKey, in: context).toString(in: context)
      #expect(uniVal == "unicode")

      let nullCharKey: StaticString = "a\0b"
      object.setProperty("null", forKey: nullCharKey, in: context)
      let hasNullChar = object.hasProperty(nullCharKey, in: context)
      #expect(hasNullChar)
      let nullCharVal = object.getProperty(forKey: nullCharKey, in: context).toString(in: context)
      #expect(nullCharVal == "null")
      object.deleteProperty(forKey: nullCharKey, in: context)
      let hasNullCharAfter = object.hasProperty(nullCharKey, in: context)
      #expect(!hasNullCharAfter)
    }
  }
}
