import Testing

@testable import SwiftyJavaScriptCore

@Test func macroDefaultSynthesisRoundtrip() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroDefaultUser(name: "alice", age: 42)
    global.setProperty(
      value, forKey: ("macroDefault"),
      in: context)

    let decoded: MacroDefaultUser = global.getProperty(
      forKey: ("macroDefault"),
      using: JSDefaultConverter<MacroDefaultUser>.self,
      in: context
    )

    #expect(decoded == value)
  }
}

@Test func macroTypeLevelDecoderEncoderOverride() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroDelegatedUser(score: 9)
    global.setProperty(
      value, forKey: ("macroDelegated"),
      in: context)

    let raw = global.getProperty(
      forKey: ("macroDelegated"), in: context)
    #expect(raw.toDouble(in: context) == 9)

    let decoded: MacroDelegatedUser = global.getProperty(
      forKey: ("macroDelegated"),
      using: JSDefaultConverter<MacroDelegatedUser>.self,
      in: context
    )
    #expect(decoded == value)
  }
}

@Test func macroFieldLevelOverrideUsesCustomConverter() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroFieldOverrideUser(name: "bob", active: true)
    global.setProperty(
      value, forKey: ("macroField"),
      in: context)

    let activeRaw = context.evaluateScript("macroField.active")
    switch consume activeRaw {
    case .value(let active):
      #expect(active.toInt32(in: context) == 1)
    case .exception:
      Issue.record("Expected macroField.active value")
    }

    _ = context.evaluateScript("macroField = { name: 'bob', active: 0 }")
    let decoded: MacroFieldOverrideUser = global.getProperty(
      forKey: ("macroField"),
      using: JSDefaultConverter<MacroFieldOverrideUser>.self,
      in: context
    )
    #expect(decoded == MacroFieldOverrideUser(name: "bob", active: false))
  }
}

@Test func macroFinalClassSerializationUsesValueSemantics() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroSerializedClass(name: "iris", active: true)
    global.setProperty(
      value, forKey: ("macroClass"),
      in: context)

    let shapeCheck = context.evaluateScript("[macroClass.name, macroClass.active].join(':')")
    switch consume shapeCheck {
    case .value(let encoded):
      #expect(encoded.toString(in: context) == "iris:1")
    case .exception:
      Issue.record("Expected serialized final class to encode as a plain JS object")
    }

    let decoded: MacroSerializedClass = global.getProperty(
      forKey: ("macroClass"),
      using: JSDefaultConverter<MacroSerializedClass>.self,
      in: context
    )
    #expect(decoded == value)
    #expect(decoded !== value)

    _ = context.evaluateScript("macroClass = { name: 'rhea', active: 0 }")
    let decodedFromObject: MacroSerializedClass = global.getProperty(
      forKey: ("macroClass"),
      using: JSDefaultConverter<MacroSerializedClass>.self,
      in: context
    )
    #expect(decodedFromObject == MacroSerializedClass(name: "rhea", active: false))
  }
}

@Test func macroEnumSynthesisUsesCaseNameStrings() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroStringEnum.running
    global.setProperty(
      value, forKey: ("macroEnum"), in: context
    )

    let raw = global.getProperty(
      forKey: ("macroEnum"), in: context)
    #expect(raw.toString(in: context) == "running")

    _ = context.evaluateScript("macroEnum = 'done'")
    let decoded: MacroStringEnum = global.getProperty(
      forKey: ("macroEnum"),
      using: JSDefaultConverter<MacroStringEnum>.self,
      in: context
    )
    #expect(decoded == .done)
  }
}

@Test func macroRawEnumSynthesisUsesRawValue() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    let value = MacroRawEnum.alpha
    global.setProperty(
      value, forKey: ("macroRawEnum"),
      in: context)

    let raw = global.getProperty(
      forKey: ("macroRawEnum"), in: context)
    #expect(raw.toString(in: context) == "A")

    _ = context.evaluateScript("macroRawEnum = 'B'")
    let decoded: MacroRawEnum = global.getProperty(
      forKey: ("macroRawEnum"),
      using: JSDefaultConverter<MacroRawEnum>.self,
      in: context
    )
    #expect(decoded == .beta)
  }
}

@Test func macroAssociatedEnumSynthesisUsesTaggedObjects() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    global.setProperty(
      MacroAssociatedEnum.idle,
      forKey: ("enumIdle"), in: context)
    global.setProperty(
      MacroAssociatedEnum.count(7),
      forKey: ("enumCount"), in: context)
    global.setProperty(
      MacroAssociatedEnum.range(3, 9),
      forKey: ("enumRange"), in: context)
    global.setProperty(
      MacroAssociatedEnum.user(id: 42, name: "neo"),
      forKey: ("enumUser"),
      in: context
    )

    let shapeCheck = context.evaluateScript(
      """
      [
        enumIdle.kind,
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
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    _ = context.evaluateScript(
      """
      globalThis.enumIdle = { kind: 'idle' }
      globalThis.enumCount = { kind: 'count', payload: 5 }
      globalThis.enumRange = { kind: 'range', payload: [1, 4] }
      globalThis.enumUser = { kind: 'user', payload: { id: 8, name: 'trinity' } }
      """)

    let idle: MacroAssociatedEnum = global.getProperty(
      forKey: ("enumIdle"),
      using: JSDefaultConverter<MacroAssociatedEnum>.self,
      in: context
    )
    let count: MacroAssociatedEnum = global.getProperty(
      forKey: ("enumCount"),
      using: JSDefaultConverter<MacroAssociatedEnum>.self,
      in: context
    )
    let range: MacroAssociatedEnum = global.getProperty(
      forKey: ("enumRange"),
      using: JSDefaultConverter<MacroAssociatedEnum>.self,
      in: context
    )
    let user: MacroAssociatedEnum = global.getProperty(
      forKey: ("enumUser"),
      using: JSDefaultConverter<MacroAssociatedEnum>.self,
      in: context
    )

    #expect(idle == .idle)
    #expect(count == .count(5))
    #expect(range == .range(1, 4))
    #expect(user == .user(id: 8, name: "trinity"))
  }
}

@Test func macroAssociatedEnumCanCustomizeTagAndPayloadKeys() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    global.setProperty(
      MacroCustomKeyAssociatedEnum.idle,
      forKey: ("customIdle"),
      in: context
    )
    global.setProperty(
      MacroCustomKeyAssociatedEnum.count(11),
      forKey: ("customCount"),
      in: context
    )
    global.setProperty(
      MacroCustomKeyAssociatedEnum.user(id: 3, name: "smith"),
      forKey: ("customUser"),
      in: context
    )

    let shapeCheck = context.evaluateScript(
      """
      [
        customIdle.type,
        customCount.data,
        customUser.data.id,
        customUser.data.name,
        typeof customUser.kind,
        typeof customUser.payload
      ].join(':')
      """)
    switch consume shapeCheck {
    case .value(let value):
      #expect(value.toString(in: context) == "idle:11:3:smith:undefined:undefined")
    case .exception:
      Issue.record("Expected custom tag and payload keys to be used for associated enum encoding")
    }

    _ = context.evaluateScript(
      """
      globalThis.customIdle = { type: 'idle' }
      globalThis.customCount = { type: 'count', data: 8 }
      globalThis.customUser = { type: 'user', data: { id: 5, name: 'oracle' } }
      """)

    let idle: MacroCustomKeyAssociatedEnum = global.getProperty(
      forKey: ("customIdle"),
      using: JSDefaultConverter<MacroCustomKeyAssociatedEnum>.self,
      in: context
    )
    let count: MacroCustomKeyAssociatedEnum = global.getProperty(
      forKey: ("customCount"),
      using: JSDefaultConverter<MacroCustomKeyAssociatedEnum>.self,
      in: context
    )
    let user: MacroCustomKeyAssociatedEnum = global.getProperty(
      forKey: ("customUser"),
      using: JSDefaultConverter<MacroCustomKeyAssociatedEnum>.self,
      in: context
    )

    #expect(idle == .idle)
    #expect(count == .count(8))
    #expect(user == .user(id: 5, name: "oracle"))
  }
}

@Test func macroAssociatedEnumCanFlattenLabeledPayloadIntoTopLevelObject() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    global.setProperty(
      MacroFlattenedAssociatedEnum.rgb(r: 1, g: 2, b: 3),
      forKey: ("flattenedRgb"),
      in: context
    )
    global.setProperty(
      MacroFlattenedAssociatedEnum.named(name: "cyan"),
      forKey: ("flattenedNamed"),
      in: context
    )
    global.setProperty(
      MacroFlattenedAssociatedEnum.idle,
      forKey: ("flattenedIdle"),
      in: context
    )

    let shapeCheck = context.evaluateScript(
      """
      [
        flattenedRgb.kind,
        flattenedRgb.r,
        flattenedRgb.g,
        flattenedRgb.b,
        typeof flattenedRgb.payload,
        flattenedNamed.kind,
        flattenedNamed.name,
        flattenedIdle.kind
      ].join(':')
      """)
    switch consume shapeCheck {
    case .value(let value):
      #expect(value.toString(in: context) == "rgb:1:2:3:undefined:named:cyan:idle")
    case .exception:
      Issue.record(
        "Expected payloadKey empty string to flatten labeled payload fields into the top-level object"
      )
    }

    _ = context.evaluateScript(
      """
      globalThis.flattenedRgb = { kind: 'rgb', r: 7, g: 8, b: 9 }
      globalThis.flattenedNamed = { kind: 'named', name: 'amber' }
      globalThis.flattenedIdle = { kind: 'idle' }
      """)

    let rgb: MacroFlattenedAssociatedEnum = global.getProperty(
      forKey: ("flattenedRgb"),
      using: JSDefaultConverter<MacroFlattenedAssociatedEnum>.self,
      in: context
    )
    let named: MacroFlattenedAssociatedEnum = global.getProperty(
      forKey: ("flattenedNamed"),
      using: JSDefaultConverter<MacroFlattenedAssociatedEnum>.self,
      in: context
    )
    let idle: MacroFlattenedAssociatedEnum = global.getProperty(
      forKey: ("flattenedIdle"),
      using: JSDefaultConverter<MacroFlattenedAssociatedEnum>.self,
      in: context
    )

    #expect(rgb == .rgb(r: 7, g: 8, b: 9))
    #expect(named == .named(name: "amber"))
    #expect(idle == .idle)
  }
}

@Test func macroAssociatedEnumFieldOverridesApplyPerPayloadField() async {
  let context = JSContext(virtualMachine: JSVirtualMachine<JavaScriptCoreEngine>())

  await context.withIsolatedGlobalObject { context, global in
    global.setProperty(
      MacroAssociatedOverrideEnum.enabled(true),
      forKey: ("enumEnabled"),
      in: context
    )
    global.setProperty(
      MacroAssociatedOverrideEnum.pair(true, false),
      forKey: ("enumPair"),
      in: context
    )
    global.setProperty(
      MacroAssociatedOverrideEnum.flags(id: 9, enabled: true),
      forKey: ("enumFlags"),
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
      globalThis.enumEnabled = { kind: 'enabled', payload: 0 }
      globalThis.enumPair = { kind: 'pair', payload: [0, 1] }
      globalThis.enumFlags = { kind: 'flags', payload: { id: 12, enabled: 0 } }
      """)

    let enabled: MacroAssociatedOverrideEnum = global.getProperty(
      forKey: ("enumEnabled"),
      using: JSDefaultConverter<MacroAssociatedOverrideEnum>.self,
      in: context
    )
    let pair: MacroAssociatedOverrideEnum = global.getProperty(
      forKey: ("enumPair"),
      using: JSDefaultConverter<MacroAssociatedOverrideEnum>.self,
      in: context
    )
    let flags: MacroAssociatedOverrideEnum = global.getProperty(
      forKey: ("enumFlags"),
      using: JSDefaultConverter<MacroAssociatedOverrideEnum>.self,
      in: context
    )

    #expect(enabled == .enabled(false))
    #expect(pair == .pair(false, true))
    #expect(flags == .flags(id: 12, enabled: false))
  }
}
