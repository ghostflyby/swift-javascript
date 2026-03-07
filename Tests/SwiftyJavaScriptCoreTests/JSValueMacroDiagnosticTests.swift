import SwiftSyntaxMacrosTestSupport
import Testing

@testable import SwiftyJavaScriptCoreMacrosPlugin

private let macroTestImplementations = [
  "JSValueAutoSerialization": JSValueAutoSerializationMacro.self
]

@Test func jsValueAutoSerializationRejectsMixedLabeledAssociatedValues() {
  assertMacroExpansion(
    """
    @JSValueAutoSerialization
    enum MixedPayloadEnum {
      case invalid(id: Int32, String)
    }
    """,
    expandedSource: """
      enum MixedPayloadEnum {
        case invalid(id: Int32, String)
      }
      """,
    diagnostics: [
      DiagnosticSpec(
        message:
          "@JSValueAutoSerialization does not support enum cases that mix labeled and unlabeled associated values",
        line: 1,
        column: 1
      )
    ],
    macros: macroTestImplementations
  )
}

@Test func jsValueAutoSerializationRejectsEmptyPayloadKeyForUnlabeledPayload() {
  assertMacroExpansion(
    """
    @JSValueAutoSerialization(payloadKey: "")
    enum InvalidFlattenedEnum {
      case rgb(Int32, Int32, Int32)
    }
    """,
    expandedSource: """
      enum InvalidFlattenedEnum {
        case rgb(Int32, Int32, Int32)
      }
      """,
    diagnostics: [
      DiagnosticSpec(
        message:
          "@JSValueAutoSerialization payloadKey cannot be empty unless every associated-value case uses labeled payload fields",
        line: 1,
        column: 1
      )
    ],
    macros: macroTestImplementations
  )
}

@Test func jsValueAutoSerializationRejectsNonFinalClassSynthesis() {
  assertMacroExpansion(
    """
    @JSValueAutoSerialization
    class NonFinalSerializedClass {
      let name: String

      init(name: String) {
        self.name = name
      }
    }
    """,
    expandedSource: """
      class NonFinalSerializedClass {
        let name: String

        init(name: String) {
          self.name = name
        }
      }
      """,
    diagnostics: [
      DiagnosticSpec(
        message:
          "@JSValueAutoSerialization automatic class synthesis currently supports final class only",
        line: 1,
        column: 1
      )
    ],
    macros: macroTestImplementations
  )
}
