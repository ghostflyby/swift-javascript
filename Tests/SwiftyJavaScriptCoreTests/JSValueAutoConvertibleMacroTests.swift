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

@Test func macroAssociatedEnumSynthesisUsesTaggedObjects() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    global.setProperty(MacroAssociatedEnum.idle, forKey: JSStringManaged("enumIdle"), in: context)
    global.setProperty(
      MacroAssociatedEnum.count(7), forKey: JSStringManaged("enumCount"), in: context)
    global.setProperty(
      MacroAssociatedEnum.range(3, 9), forKey: JSStringManaged("enumRange"), in: context)
    global.setProperty(
      MacroAssociatedEnum.user(id: 42, name: "neo"),
      forKey: JSStringManaged("enumUser"),
      in: context
    )

    let shapeCheck = context.evaluateScript(
      """
      [
        enumIdle.tag,
        enumCount.payload,
        Array.isArray(enumRange.payload),
        enumRange.payload[0] + enumRange.payload[1],
        enumUser.payload.id,
        enumUser.payload.name
      ].join(':')
      """)
    switch consume shapeCheck {
    case .value(let value):
      #expect(value.toString(in: context) == "idle:7:true:12:42:neo")
    case .exception:
      Issue.record("Expected associated enum payloads to be encoded as tagged objects")
    }
  }
}

@Test func macroAssociatedEnumCanDecodeTaggedObjects() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    _ = context.evaluateScript(
      """
      globalThis.enumIdle = { tag: 'idle' }
      globalThis.enumCount = { tag: 'count', payload: 5 }
      globalThis.enumRange = { tag: 'range', payload: [1, 4] }
      globalThis.enumUser = { tag: 'user', payload: { id: 8, name: 'trinity' } }
      """)

    let idle: MacroAssociatedEnum = global.getProperty(
      forKey: JSStringManaged("enumIdle"),
      using: JSDefaultConverter<MacroAssociatedEnum>.self,
      in: context
    )
    let count: MacroAssociatedEnum = global.getProperty(
      forKey: JSStringManaged("enumCount"),
      using: JSDefaultConverter<MacroAssociatedEnum>.self,
      in: context
    )
    let range: MacroAssociatedEnum = global.getProperty(
      forKey: JSStringManaged("enumRange"),
      using: JSDefaultConverter<MacroAssociatedEnum>.self,
      in: context
    )
    let user: MacroAssociatedEnum = global.getProperty(
      forKey: JSStringManaged("enumUser"),
      using: JSDefaultConverter<MacroAssociatedEnum>.self,
      in: context
    )

    #expect(idle == .idle)
    #expect(count == .count(5))
    #expect(range == .range(1, 4))
    #expect(user == .user(id: 8, name: "trinity"))
  }
}

@Test func macroAssociatedEnumFieldOverridesApplyPerPayloadField() async {
  let context = JSContext(virtualMachine: SwiftyJavaScriptCore.JSVirtualMachine())

  await context.withIsolatedGlobalObject { context, global in
    global.setProperty(
      MacroAssociatedOverrideEnum.enabled(true),
      forKey: JSStringManaged("enumEnabled"),
      in: context
    )
    global.setProperty(
      MacroAssociatedOverrideEnum.pair(true, false),
      forKey: JSStringManaged("enumPair"),
      in: context
    )
    global.setProperty(
      MacroAssociatedOverrideEnum.flags(id: 9, enabled: true),
      forKey: JSStringManaged("enumFlags"),
      in: context
    )

    let shapeCheck = context.evaluateScript(
      """
      [
        enumEnabled.payload,
        enumPair.payload[0],
        enumPair.payload[1],
        enumFlags.payload.id,
        enumFlags.payload.enabled
      ].join(':')
      """)
    switch consume shapeCheck {
    case .value(let value):
      #expect(value.toString(in: context) == "1:1:0:9:1")
    case .exception:
      Issue.record(
        "Expected associated enum field-level converters to affect encoded payload values")
    }

    _ = context.evaluateScript(
      """
      globalThis.enumEnabled = { tag: 'enabled', payload: 0 }
      globalThis.enumPair = { tag: 'pair', payload: [0, 1] }
      globalThis.enumFlags = { tag: 'flags', payload: { id: 12, enabled: 0 } }
      """)

    let enabled: MacroAssociatedOverrideEnum = global.getProperty(
      forKey: JSStringManaged("enumEnabled"),
      using: JSDefaultConverter<MacroAssociatedOverrideEnum>.self,
      in: context
    )
    let pair: MacroAssociatedOverrideEnum = global.getProperty(
      forKey: JSStringManaged("enumPair"),
      using: JSDefaultConverter<MacroAssociatedOverrideEnum>.self,
      in: context
    )
    let flags: MacroAssociatedOverrideEnum = global.getProperty(
      forKey: JSStringManaged("enumFlags"),
      using: JSDefaultConverter<MacroAssociatedOverrideEnum>.self,
      in: context
    )

    #expect(enabled == .enabled(false))
    #expect(pair == .pair(false, true))
    #expect(flags == .flags(id: 12, enabled: false))
  }
}
