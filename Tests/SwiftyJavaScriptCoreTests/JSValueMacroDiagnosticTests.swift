import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

@testable import SwiftyJavaScriptCoreMacrosPlugin

private func macroTestImplementations() -> [String: Macro.Type] {
  [
    "JSValueAutoSerialization": JSValueAutoSerializationMacro.self as Macro.Type,
    "JSClassAutoConvertible": JSClassAutoConvertibleMacro.self as Macro.Type,
    "JSClassFunction": JSValueFieldMarkerMacro.self as Macro.Type,
    "JSClassFunctionArguments": JSValueFieldMarkerMacro.self as Macro.Type,
    "JSClassFunctionReturn": JSValueFieldMarkerMacro.self as Macro.Type,
    "JSClassFunctionError": JSValueFieldMarkerMacro.self as Macro.Type,
  ]
}

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
    macros: macroTestImplementations()
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
    macros: macroTestImplementations()
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
    macros: macroTestImplementations()
  )
}

@Test func jsClassAutoConvertibleRejectsStaticFunctionExport() {
  assertMacroExpansion(
    """
    @JSClassAutoConvertible
    class InvalidStaticExport {
      @JSClassFunction
      static func build() -> String {
        "value"
      }
    }
    """,
    expandedSource: """
      class InvalidStaticExport {
        static func build() -> String {
          "value"
        }
      }

      extension InvalidStaticExport: JSClassValueConvertible {
      }
      """,
    diagnostics: [
      DiagnosticSpec(
        message: "@JSClassFunction supports instance methods only",
        line: 1,
        column: 1
      )
    ],
    macros: macroTestImplementations()
  )
}

@Test func jsClassAutoConvertibleRejectsMismatchedArgumentConverters() {
  assertMacroExpansion(
    """
    @JSClassAutoConvertible
    class InvalidArgumentConverters {
      @JSClassFunction
      @JSClassFunctionArguments(String.self)
      func render(_ lhs: String, _ rhs: String) -> String {
        lhs + rhs
      }
    }
    """,
    expandedSource: """
      class InvalidArgumentConverters {
        func render(_ lhs: String, _ rhs: String) -> String {
          lhs + rhs
        }
      }

      extension InvalidArgumentConverters: JSClassValueConvertible {
      }
      """,
    diagnostics: [
      DiagnosticSpec(
        message: "@JSClassFunctionArguments count must match the number of method parameters",
        line: 1,
        column: 1
      )
    ],
    macros: macroTestImplementations()
  )
}

@Test func jsClassAutoConvertibleRejectsErrorEncoderOnNonThrowingMethod() {
  assertMacroExpansion(
    """
    @JSClassAutoConvertible
    class InvalidErrorEncoder {
      @JSClassFunction
      @JSClassFunctionError(String.self)
      func render() -> String {
        "value"
      }
    }
    """,
    expandedSource: """
      class InvalidErrorEncoder {
        func render() -> String {
          "value"
        }
      }

      extension InvalidErrorEncoder: JSClassValueConvertible {
      }
      """,
    diagnostics: [
      DiagnosticSpec(
        message: "@JSClassFunctionError can only be used on throwing methods",
        line: 1,
        column: 1
      )
    ],
    macros: macroTestImplementations()
  )
}
