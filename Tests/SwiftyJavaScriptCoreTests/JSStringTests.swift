import Testing

@testable import SwiftyJavaScriptCore

@Test func stringInitFromJSStringHandle() {
  let managed = JSStringManaged("hello")
  let swiftString = String(
    jsStringHandle: managed.jsStringHandle,
    engine: JavaScriptCoreEngine.self
  )

  #expect(swiftString == "hello")
}

@Test func jsStringManagedBasics() {
  let value = JSStringManaged("abc")

  #expect(value.string == "abc")
  #expect(value.cached == "abc")
}

@Test func jsStringManagedEmpty() {
  #expect(JSStringManaged.empty.string == "")
}

@Test func jsStringGroupInitAndEquality() {
  let managed = JSStringManaged("group")
  let grouped = JSStringManaged(group: managed)

  let eq1 = grouped == managed
  let ne = grouped != JSStringManaged("other")

  #expect(eq1)
  #expect(ne)
}

@Test func jsStringValueInitsAndCaching() {
  let base = JSStringValue("cache")
  let noCache = JSStringValue(base, caching: false)
  let withCache = JSStringValue(base, caching: true)
  let fromManaged = JSStringValue(JSStringManaged("m"), caching: true)

  let baseCached = base.cached
  let noCacheString = noCache.string
  let withCacheCached = withCache.cached
  let fromManagedCached = fromManaged.cached

  #expect(baseCached == "cache")
  #expect(noCacheString == "cache")
  #expect(withCacheCached == "cache")
  #expect(fromManagedCached == "m")
}
