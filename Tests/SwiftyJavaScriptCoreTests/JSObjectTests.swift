import Testing

@testable import SwiftyJavaScriptCore

@Test func propertyAttributesOptionSet() {
  let value: JSPropertyAttributes = [.dontDelete, .readOnly]

  #expect(value.contains(.dontDelete))
  #expect(value.contains(.readOnly))
  #expect(!value.contains(.dontEnum))
  #expect(JSPropertyAttributes.none.rawValue == 0)
}
