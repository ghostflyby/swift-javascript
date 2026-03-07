import SwiftSyntaxMacrosTestSupport
import Testing

@testable import SwiftyJavaScriptCoreMacrosPlugin

private let macroTestImplementations = [
  "JSValueAutoConvertible": JSValueAutoConvertibleMacro.self
]

@Test func jsValueAutoConvertibleRejectsMixedLabeledAssociatedValues() {
  assertMacroExpansion(
    """
    @JSValueAutoConvertible
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
          "@JSValueAutoConvertible does not support enum cases that mix labeled and unlabeled associated values",
        line: 1,
        column: 1
      )
    ],
    macros: macroTestImplementations
  )
}

@Test func jsValueAutoConvertibleRejectsEmptyPayloadKeyForUnlabeledPayload() {
  assertMacroExpansion(
    """
    @JSValueAutoConvertible(payloadKey: "")
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
          "@JSValueAutoConvertible payloadKey cannot be empty unless every associated-value case uses labeled payload fields",
        line: 1,
        column: 1
      )
    ],
    macros: macroTestImplementations
  )
}
