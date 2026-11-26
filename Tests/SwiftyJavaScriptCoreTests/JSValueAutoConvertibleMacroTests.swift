import JavaScriptCore
import Testing

@testable import SwiftyJavaScriptCore

private func makeMacroHandles() -> (runtime: JSContextGroupRef, contextRef: JSGlobalContextRef) {
  let runtime = JSCEngine.makeRuntime()
  guard let contextHandle = JSCEngine.makeBorrowedContextHandleFromRuntime(in: runtime)
  else {
    preconditionFailure("JSCEngine could not create a context handle")
  }
  return (runtime, contextHandle)
}

@Test func macroDefaultSynthesisRoundtrip() {
  let (runtime, contextHandle) = makeMacroHandles()
  _ = runtime
  let context = JSCInstantContext(contextRef: contextHandle)
  let value = MacroDefaultUser(name: "alice", age: 42)
  context.setGlobalProperty(value, forKey: "macroDefault")

  let decoded = try? MacroDefaultUser.tryDecode(
    context.getGlobalProperty(forKey: "macroDefault"), in: context)

  #expect(decoded == value)
}

@Test func macroTypeLevelDecoderEncoderOverride() {
  let (runtime, contextHandle) = makeMacroHandles()
  _ = runtime
  let context = JSCInstantContext(contextRef: contextHandle)
  let value = MacroDelegatedUser(score: 9)
  context.setGlobalProperty(value, forKey: "macroDelegated")

  let raw = context.getGlobalProperty(forKey: "macroDelegated")
  #expect(raw.toNumber() == 9)

  let decoded = try? MacroDelegatedUser.tryDecode(
    context.getGlobalProperty(forKey: "macroDelegated"), in: context)
  #expect(decoded == value)
}

@Test func macroFieldLevelOverrideUsesCustomConverter() {
  let (runtime, contextHandle) = makeMacroHandles()
  _ = runtime
  let context = JSCInstantContext(contextRef: contextHandle)
  let value = MacroFieldOverrideUser(name: "bob", active: true)
  context.setGlobalProperty(value, forKey: "macroField")

  let activeRaw = context.evaluateScript("macroField.active")
  switch consume activeRaw {
  case .value(let active):
    #expect(active.toNumber() == 1)
  case .exception:
    Issue.record("Expected macroField.active value")
  }

  _ = context.evaluateScript("macroField = { name: 'bob', active: 0 }")
  let decoded = try? MacroFieldOverrideUser.tryDecode(
    context.getGlobalProperty(forKey: "macroField"), in: context)
  #expect(decoded == MacroFieldOverrideUser(name: "bob", active: false))
}

@Test func macroFinalClassSerializationUsesValueSemantics() {
  let (runtime, contextHandle) = makeMacroHandles()
  _ = runtime
  let context = JSCInstantContext(contextRef: contextHandle)
  let value = MacroSerializedClass(name: "iris", active: true)
  context.setGlobalProperty(value, forKey: "macroClass")

  let shapeCheck = context.evaluateScript("[macroClass.name, macroClass.active].join(':')")
  switch consume shapeCheck {
  case .value(let encoded):
    #expect(encoded.toString() == "iris:1")
  case .exception:
    Issue.record("Expected serialized final class to encode as a plain JS object")
  }

  let decoded = try? MacroSerializedClass.tryDecode(
    context.getGlobalProperty(forKey: "macroClass"), in: context)
  #expect(decoded == value)
  #expect(decoded !== value)

  _ = context.evaluateScript("macroClass = { name: 'rhea', active: 0 }")
  let decodedFromObject = try? MacroSerializedClass.tryDecode(
    context.getGlobalProperty(forKey: "macroClass"), in: context)
  #expect(decodedFromObject == MacroSerializedClass(name: "rhea", active: false))
}

@Test func macroEnumSynthesisUsesCaseNameStrings() {
  let (runtime, contextHandle) = makeMacroHandles()
  _ = runtime
  let context = JSCInstantContext(contextRef: contextHandle)
  let value = MacroStringEnum.running
  context.setGlobalProperty(value, forKey: "macroEnum")

  let raw = context.getGlobalProperty(forKey: "macroEnum")
  #expect(raw.toString() == "running")

  _ = context.evaluateScript("macroEnum = 'done'")
  let decoded = try? MacroStringEnum.tryDecode(
    context.getGlobalProperty(forKey: "macroEnum"), in: context)
  #expect(decoded == .done)
}

@Test func macroRawEnumSynthesisUsesRawValue() {
  let (runtime, contextHandle) = makeMacroHandles()
  _ = runtime
  let context = JSCInstantContext(contextRef: contextHandle)
  let value = MacroRawEnum.alpha
  context.setGlobalProperty(value, forKey: "macroRawEnum")

  let raw = context.getGlobalProperty(forKey: "macroRawEnum")
  #expect(raw.toString() == "A")

  _ = context.evaluateScript("macroRawEnum = 'B'")
  let decoded = try? MacroRawEnum.tryDecode(
    context.getGlobalProperty(forKey: "macroRawEnum"), in: context)
  #expect(decoded == .beta)
}

@Test func macroAssociatedEnumSynthesisUsesTaggedObjects() {
  let (runtime, contextHandle) = makeMacroHandles()
  _ = runtime
  let context = JSCInstantContext(contextRef: contextHandle)
  context.setGlobalProperty(MacroAssociatedEnum.idle, forKey: "enumIdle")
  context.setGlobalProperty(MacroAssociatedEnum.count(7), forKey: "enumCount")
  context.setGlobalProperty(MacroAssociatedEnum.range(3, 9), forKey: "enumRange")
  context.setGlobalProperty(MacroAssociatedEnum.user(id: 42, name: "neo"), forKey: "enumUser")

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
    #expect(value.toString() == "idle:7:true:12:42:neo")
  case .exception:
    Issue.record("Expected associated enum payloads to be encoded as tagged objects")
  }
}

@Test func macroAssociatedEnumCanDecodeTaggedObjects() {
  let (runtime, contextHandle) = makeMacroHandles()
  _ = runtime
  let context = JSCInstantContext(contextRef: contextHandle)
  _ = context.evaluateScript(
    """
    globalThis.enumIdle = { kind: 'idle' }
    globalThis.enumCount = { kind: 'count', payload: 5 }
    globalThis.enumRange = { kind: 'range', payload: [1, 4] }
    globalThis.enumUser = { kind: 'user', payload: { id: 8, name: 'trinity' } }
    """)

  let idle = try? MacroAssociatedEnum.tryDecode(
    context.getGlobalProperty(forKey: "enumIdle"), in: context)
  let count = try? MacroAssociatedEnum.tryDecode(
    context.getGlobalProperty(forKey: "enumCount"), in: context)
  let range = try? MacroAssociatedEnum.tryDecode(
    context.getGlobalProperty(forKey: "enumRange"), in: context)
  let user = try? MacroAssociatedEnum.tryDecode(
    context.getGlobalProperty(forKey: "enumUser"), in: context)

  #expect(idle == .idle)
  #expect(count == .count(5))
  #expect(range == .range(1, 4))
  #expect(user == .user(id: 8, name: "trinity"))
}

@Test func macroAssociatedEnumCanCustomizeTagAndPayloadKeys() {
  let (runtime, contextHandle) = makeMacroHandles()
  _ = runtime
  let context = JSCInstantContext(contextRef: contextHandle)
  context.setGlobalProperty(MacroCustomKeyAssociatedEnum.idle, forKey: "customIdle")
  context.setGlobalProperty(MacroCustomKeyAssociatedEnum.count(11), forKey: "customCount")
  context.setGlobalProperty(
    MacroCustomKeyAssociatedEnum.user(id: 3, name: "smith"), forKey: "customUser")

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
    #expect(value.toString() == "idle:11:3:smith:undefined:undefined")
  case .exception:
    Issue.record("Expected custom tag and payload keys to be used for associated enum encoding")
  }

  _ = context.evaluateScript(
    """
    globalThis.customIdle = { type: 'idle' }
    globalThis.customCount = { type: 'count', data: 8 }
    globalThis.customUser = { type: 'user', data: { id: 5, name: 'oracle' } }
    """)

  let idle = try? MacroCustomKeyAssociatedEnum.tryDecode(
    context.getGlobalProperty(forKey: "customIdle"), in: context)
  let count = try? MacroCustomKeyAssociatedEnum.tryDecode(
    context.getGlobalProperty(forKey: "customCount"), in: context)
  let user = try? MacroCustomKeyAssociatedEnum.tryDecode(
    context.getGlobalProperty(forKey: "customUser"), in: context)

  #expect(idle == .idle)
  #expect(count == .count(8))
  #expect(user == .user(id: 5, name: "oracle"))
}

@Test func macroAssociatedEnumCanFlattenLabeledPayloadIntoTopLevelObject() {
  let (runtime, contextHandle) = makeMacroHandles()
  _ = runtime
  let context = JSCInstantContext(contextRef: contextHandle)
  context.setGlobalProperty(
    MacroFlattenedAssociatedEnum.rgb(r: 1, g: 2, b: 3), forKey: "flattenedRgb")
  context.setGlobalProperty(
    MacroFlattenedAssociatedEnum.named(name: "cyan"), forKey: "flattenedNamed")
  context.setGlobalProperty(MacroFlattenedAssociatedEnum.idle, forKey: "flattenedIdle")

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
    #expect(value.toString() == "rgb:1:2:3:undefined:named:cyan:idle")
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

  let rgb = try? MacroFlattenedAssociatedEnum.tryDecode(
    context.getGlobalProperty(forKey: "flattenedRgb"), in: context)
  let named = try? MacroFlattenedAssociatedEnum.tryDecode(
    context.getGlobalProperty(forKey: "flattenedNamed"), in: context)
  let idle = try? MacroFlattenedAssociatedEnum.tryDecode(
    context.getGlobalProperty(forKey: "flattenedIdle"), in: context)

  #expect(rgb == .rgb(r: 7, g: 8, b: 9))
  #expect(named == .named(name: "amber"))
  #expect(idle == .idle)
}

@Test func macroAssociatedEnumFieldOverridesApplyPerPayloadField() {
  let (runtime, contextHandle) = makeMacroHandles()
  _ = runtime
  let context = JSCInstantContext(contextRef: contextHandle)
  context.setGlobalProperty(MacroAssociatedOverrideEnum.enabled(true), forKey: "enumEnabled")
  context.setGlobalProperty(MacroAssociatedOverrideEnum.pair(true, false), forKey: "enumPair")
  context.setGlobalProperty(
    MacroAssociatedOverrideEnum.flags(id: 9, enabled: true), forKey: "enumFlags")

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
    #expect(value.toString() == "1:1:0:9:1")
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

  let enabled = try? MacroAssociatedOverrideEnum.tryDecode(
    context.getGlobalProperty(forKey: "enumEnabled"), in: context)
  let pair = try? MacroAssociatedOverrideEnum.tryDecode(
    context.getGlobalProperty(forKey: "enumPair"), in: context)
  let flags = try? MacroAssociatedOverrideEnum.tryDecode(
    context.getGlobalProperty(forKey: "enumFlags"), in: context)

  #expect(enabled == .enabled(false))
  #expect(pair == .pair(false, true))
  #expect(flags == .flags(id: 12, enabled: false))
}
