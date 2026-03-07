import Testing

@testable import SwiftyJavaScriptCore

@Test func macroDefaultSynthesisRoundtrip() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroDefaultUser(name: "alice", age: 42)
    global.setProperty(value, forKey: JSStringManaged("macroDefault"), in: context)

    let decoded: MacroDefaultUser = global.getProperty(
      forKey: JSStringManaged("macroDefault"),
      using: JSDefaultConverter<MacroDefaultUser>.self,
      in: context
    )

    #expect(decoded == value)
  }
}

@Test func macroTypeLevelDecoderEncoderOverride() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroDelegatedUser(score: 9)
    global.setProperty(value, forKey: JSStringManaged("macroDelegated"), in: context)

    let raw = global.getProperty(forKey: JSStringManaged("macroDelegated"), in: context)
    #expect(raw.toDouble(in: context) == 9)

    let decoded: MacroDelegatedUser = global.getProperty(
      forKey: JSStringManaged("macroDelegated"),
      using: JSDefaultConverter<MacroDelegatedUser>.self,
      in: context
    )
    #expect(decoded == value)
  }
}

@Test func macroFieldLevelOverrideUsesCustomConverter() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroFieldOverrideUser(name: "bob", active: true)
    global.setProperty(value, forKey: JSStringManaged("macroField"), in: context)

    let activeRaw = context.evaluateScript("macroField.active")
    switch consume activeRaw {
    case .value(let active):
      #expect(active.toInt32(in: context) == 1)
    case .exception:
      Issue.record("Expected macroField.active value")
    }

    _ = context.evaluateScript("macroField = { name: 'bob', active: 0 }")
    let decoded: MacroFieldOverrideUser = global.getProperty(
      forKey: JSStringManaged("macroField"),
      using: JSDefaultConverter<MacroFieldOverrideUser>.self,
      in: context
    )
    #expect(decoded == MacroFieldOverrideUser(name: "bob", active: false))
  }
}

@Test func macroEnumSynthesisUsesCaseNameStrings() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroStringEnum.running
    global.setProperty(value, forKey: JSStringManaged("macroEnum"), in: context)

    let raw = global.getProperty(forKey: JSStringManaged("macroEnum"), in: context)
    #expect(raw.toString(in: context) == "running")

    _ = context.evaluateScript("macroEnum = 'done'")
    let decoded: MacroStringEnum = global.getProperty(
      forKey: JSStringManaged("macroEnum"),
      using: JSDefaultConverter<MacroStringEnum>.self,
      in: context
    )
    #expect(decoded == .done)
  }
}

@Test func macroRawEnumSynthesisUsesRawValue() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroRawEnum.alpha
    global.setProperty(value, forKey: JSStringManaged("macroRawEnum"), in: context)

    let raw = global.getProperty(forKey: JSStringManaged("macroRawEnum"), in: context)
    #expect(raw.toString(in: context) == "alpha")

    _ = context.evaluateScript("macroRawEnum = 'beta'")
    let decoded: MacroRawEnum = global.getProperty(
      forKey: JSStringManaged("macroRawEnum"),
      using: JSDefaultConverter<MacroRawEnum>.self,
      in: context
    )
    #expect(decoded == .beta)
  }
}
