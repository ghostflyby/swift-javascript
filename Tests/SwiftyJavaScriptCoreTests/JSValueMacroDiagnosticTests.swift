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
