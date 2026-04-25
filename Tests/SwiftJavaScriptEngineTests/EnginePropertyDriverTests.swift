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
}

private enum SetGetHasDeletePropertyWithStringKey: ScriptEngineAssertion {
  static func run<E: JSEngine>(_: E.Type) async where E.Engine == E {
    let context = JSContext<E>()

    await context.withInstantContext { context in
      let object = context.makeObject()
      let key = JSStringManaged<E>("strKey")
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
      let key = JSStringManaged<E>("locked")

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
      let hiddenKey = JSStringManaged<E>("hiddenFlag")
      let pinnedKey = JSStringManaged<E>("pinnedFlag")

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
