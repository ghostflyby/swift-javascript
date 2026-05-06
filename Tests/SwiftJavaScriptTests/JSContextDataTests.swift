import Testing

@testable import SwiftJavaScript

private enum StringContextDataKey: JSContextDataKey {
  static let defaultValue: String? = "default"
}

private enum IntContextDataKey: JSContextDataKey {
  typealias Value = Int
}

private enum OptionalContextDataKey: JSContextDataKey {
  typealias Value = Int?
}

@Test func contextDataUsesMarkerTypeIdentityAndDefaultValues() async {
  let context = JSContext<MockEngine>()

  let defaultValue: String? = await context.data(for: StringContextDataKey.self)
  let missingInt: Int? = await context.data(for: IntContextDataKey.self)

  #expect(defaultValue == "default")
  #expect(missingInt == nil)

  await context.setData("stored", for: StringContextDataKey.self)
  await context.setData(42, for: IntContextDataKey.self)

  let storedString: String? = await context.data(for: StringContextDataKey.self)
  let storedInt: Int? = await context.data(for: IntContextDataKey.self)

  #expect(storedString == "stored")
  #expect(storedInt == 42)
}

@Test func contextDataOverwritesAndRemovesValues() async {
  let context = JSContext<MockEngine>()

  await context.setData(1, for: IntContextDataKey.self)
  await context.setData(2, for: IntContextDataKey.self)
  let overwritten: Int? = await context.data(for: IntContextDataKey.self)

  await context.setData(nil, for: IntContextDataKey.self)
  let removed: Int? = await context.data(for: IntContextDataKey.self)

  #expect(overwritten == 2)
  #expect(removed == nil)
}

@Test func contextDataCanStoreSemanticOptionalNil() async {
  let context = JSContext<MockEngine>()

  await context.setData(.some(nil), for: OptionalContextDataKey.self)
  let stored: Int?? = await context.data(for: OptionalContextDataKey.self)

  #expect(stored != nil)
  #expect(stored! == nil)
}

@Test func contextDataIsSeparatePerContext() async {
  let first = JSContext<MockEngine>()
  let second = JSContext<MockEngine>()

  await first.setData("first", for: StringContextDataKey.self)
  await second.setData("second", for: StringContextDataKey.self)

  let firstValue: String? = await first.data(for: StringContextDataKey.self)
  let secondValue: String? = await second.data(for: StringContextDataKey.self)

  #expect(firstValue == "first")
  #expect(secondValue == "second")
}

@Test func contextAndInstantContextShareData() async {
  let context = JSContext<MockEngine>()

  await context.setData("actor", for: StringContextDataKey.self)
  let instantRead: String? = await context.withInstantContext {
    $0.data(for: StringContextDataKey.self)
  }

  await context.withInstantContext {
    $0.setData("instant", for: StringContextDataKey.self)
  }
  let actorRead: String? = await context.data(for: StringContextDataKey.self)

  #expect(instantRead == "actor")
  #expect(actorRead == "instant")
}
