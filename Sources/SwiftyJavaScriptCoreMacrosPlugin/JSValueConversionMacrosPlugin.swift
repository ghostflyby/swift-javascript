import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private struct MacroUsageError: Error, CustomStringConvertible {
  let description: String
}

private struct FieldOverrideSpec {
  let selector: String?
  let decoder: String?
  let encoder: String?
}

private struct JSValueAutoSerializationOptions {
  let typeArguments: [String]
  let tagKey: String
  let payloadKey: String
  let isPayloadKeyExplicit: Bool
}

private enum ParsedAttributeArgument {
  case string(String)
  case type(String)
}

private struct ParsedLabeledAttributeArgument {
  let label: String?
  let value: ParsedAttributeArgument
}

private struct PropertyPlan {
  let name: String
  let typeName: String
  let isMutable: Bool
  let decoderOverride: String?
  let encoderOverride: String?
}

private struct MethodParameterPlan {
  let externalName: String?
  let localName: String
  let typeName: String
  let decoderOverride: String?
}

private struct MethodPlan {
  let swiftName: String
  let jsName: String
  let parameters: [MethodParameterPlan]
  let returnTypeName: String?
  let returnEncoder: String?
  let errorEncoder: String?
  let isThrowing: Bool
}

private struct MethodExportSpec {
  let jsName: String?
  let argumentDecoders: [String]?
  let returnEncoder: String?
  let errorEncoder: String?
}

private func trimmed(_ raw: String) -> String {
  raw.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func stripDotSelf(_ raw: String) -> String {
  let value = trimmed(raw)
  if value.hasSuffix(".self") {
    return String(value.dropLast(5))
  }
  return value
}

private func parseAttributeArguments(from node: AttributeSyntax) -> [ParsedAttributeArgument] {
  parseLabeledAttributeArguments(from: node).map(\.value)
}

private func parseLabeledAttributeArguments(from node: AttributeSyntax)
  -> [ParsedLabeledAttributeArgument]
{
  guard let arguments = node.arguments,
    case .argumentList(let list) = arguments
  else {
    return []
  }

  return list.map { element in
    let parsedValue: ParsedAttributeArgument
    if let literal = element.expression.as(StringLiteralExprSyntax.self),
      literal.segments.count == 1,
      case .stringSegment(let segment) = literal.segments.first
    {
      parsedValue = .string(segment.content.text)
    } else {
      parsedValue = .type(stripDotSelf(element.expression.description))
    }

    return ParsedLabeledAttributeArgument(
      label: element.label?.text,
      value: parsedValue
    )
  }
}

private func parseTypeArguments(from node: AttributeSyntax) -> [String] {
  parseAttributeArguments(from: node).compactMap { argument in
    switch argument {
    case .string:
      return nil
    case .type(let typeName):
      return typeName
    }
  }
}

private func parseAutoSerializationOptions(from node: AttributeSyntax) throws(MacroUsageError)
  -> JSValueAutoSerializationOptions
{
  var typeArguments: [String] = []
  var tagKey = "kind"
  var payloadKey = "payload"
  var isPayloadKeyExplicit = false

  for argument in parseLabeledAttributeArguments(from: node) {
    switch (argument.label, argument.value) {
    case (nil, .type(let typeName)):
      typeArguments.append(typeName)
    case ("tagKey", .string(let value)):
      tagKey = value
    case ("payloadKey", .string(let value)):
      payloadKey = value
      isPayloadKeyExplicit = true
    case ("tagKey", .type), ("payloadKey", .type):
      throw MacroUsageError(
        description:
          "@JSValueAutoSerialization tagKey and payloadKey arguments must be string literals"
      )
    case (.some(let label), _):
      throw MacroUsageError(
        description: "@JSValueAutoSerialization does not support argument label \"\(label)\""
      )
    case (nil, .string):
      throw MacroUsageError(
        description: "@JSValueAutoSerialization unnamed string arguments are not supported"
      )
    }
  }

  return JSValueAutoSerializationOptions(
    typeArguments: typeArguments,
    tagKey: tagKey,
    payloadKey: payloadKey,
    isPayloadKeyExplicit: isPayloadKeyExplicit
  )
}

private func parseFieldOverrideSpec(from attribute: AttributeSyntax) -> FieldOverrideSpec? {
  guard let nameSyntax = attribute.attributeName.as(IdentifierTypeSyntax.self) else {
    return nil
  }

  let name = nameSyntax.name.text
  let arguments = parseAttributeArguments(from: attribute)
  let selector: String?
  let payloadArguments: ArraySlice<ParsedAttributeArgument>
  if case .string(let value)? = arguments.first {
    selector = value
    payloadArguments = arguments.dropFirst()
  } else {
    selector = nil
    payloadArguments = arguments[...]
  }

  func payloadType(at index: Int) -> String? {
    guard index >= 0, index < payloadArguments.count else {
      return nil
    }
    let element = payloadArguments[
      payloadArguments.index(payloadArguments.startIndex, offsetBy: index)]
    switch element {
    case .string:
      return nil
    case .type(let typeName):
      return typeName
    }
  }

  switch name {
  case "JSValueFieldCoding":
    if let converter = payloadType(at: 0) {
      return FieldOverrideSpec(
        selector: selector,
        decoder: converter,
        encoder: payloadType(at: 1) ?? converter
      )
    }
  case "JSValueFieldDecoding":
    if let decoder = payloadType(at: 0) {
      return FieldOverrideSpec(selector: selector, decoder: decoder, encoder: nil)
    }
  case "JSValueFieldEncoding":
    if let encoder = payloadType(at: 0) {
      return FieldOverrideSpec(selector: selector, decoder: nil, encoder: encoder)
    }
  default:
    return nil
  }

  return nil
}

private func parseFieldOverrides(from attributes: AttributeListSyntax?) -> (
  decoder: String?, encoder: String?
) {
  guard let attributes else {
    return (nil, nil)
  }

  var decoder: String?
  var encoder: String?

  for element in attributes {
    guard case .attribute(let attribute) = element,
      let override = parseFieldOverrideSpec(from: attribute)
    else {
      continue
    }

    if let overrideDecoder = override.decoder {
      decoder = overrideDecoder
    }
    if let overrideEncoder = override.encoder {
      encoder = overrideEncoder
    }
  }

  return (decoder, encoder)
}

private func parseMethodExportSpec(from attributes: AttributeListSyntax?) throws(MacroUsageError)
  -> MethodExportSpec?
{
  guard let attributes else {
    return nil
  }

  var isExported = false
  var jsName: String?
  var argumentDecoders: [String]?
  var returnEncoder: String?
  var errorEncoder: String?

  for element in attributes {
    guard case .attribute(let attribute) = element,
      let nameSyntax = attribute.attributeName.as(IdentifierTypeSyntax.self)
    else {
      continue
    }

    let name = nameSyntax.name.text
    switch name {
    case "JSClassFunction":
      isExported = true
      let arguments = parseAttributeArguments(from: attribute)
      if arguments.isEmpty {
        break
      }
      guard arguments.count == 1,
        case .string(let value) = arguments[0]
      else {
        throw MacroUsageError(
          description: "@JSClassFunction accepts at most one string literal function name"
        )
      }
      jsName = value
    case "JSClassFunctionArguments":
      let decoders = parseTypeArguments(from: attribute)
      guard !decoders.isEmpty else {
        throw MacroUsageError(
          description: "@JSClassFunctionArguments requires at least one decoder type"
        )
      }
      argumentDecoders = decoders
    case "JSClassFunctionReturn":
      let encoders = parseTypeArguments(from: attribute)
      guard encoders.count == 1 else {
        throw MacroUsageError(
          description: "@JSClassFunctionReturn requires exactly one encoder type"
        )
      }
      returnEncoder = encoders[0]
    case "JSClassFunctionError":
      let encoders = parseTypeArguments(from: attribute)
      guard encoders.count == 1 else {
        throw MacroUsageError(
          description: "@JSClassFunctionError requires exactly one encoder type"
        )
      }
      errorEncoder = encoders[0]
    default:
      continue
    }
  }

  if !isExported {
    if argumentDecoders != nil || returnEncoder != nil || errorEncoder != nil {
      throw MacroUsageError(
        description:
          "@JSClassFunctionArguments, @JSClassFunctionReturn, and @JSClassFunctionError require @JSClassFunction on the same method"
      )
    }
    return nil
  }

  return MethodExportSpec(
    jsName: jsName,
    argumentDecoders: argumentDecoders,
    returnEncoder: returnEncoder,
    errorEncoder: errorEncoder
  )
}

private func parseEnumFieldOverrides(from attributes: AttributeListSyntax?)
  throws(MacroUsageError) -> [String: FieldOverrideSpec]
{
  guard let attributes else {
    return [:]
  }

  var overrides: [String: FieldOverrideSpec] = [:]
  for element in attributes {
    guard case .attribute(let attribute) = element,
      let override = parseFieldOverrideSpec(from: attribute)
    else {
      continue
    }

    guard let selector = override.selector else {
      continue
    }

    overrides[selector] = override
  }

  return overrides
}

private func collectStoredProperties(from members: MemberBlockItemListSyntax) -> [PropertyPlan] {
  var plans: [PropertyPlan] = []

  for member in members {
    guard let variable = member.decl.as(VariableDeclSyntax.self) else {
      continue
    }
    if variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) {
      continue
    }

    let overrides = parseFieldOverrides(from: variable.attributes)

    for binding in variable.bindings {
      guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
        continue
      }
      guard let typeAnnotation = binding.typeAnnotation else {
        continue
      }
      if binding.accessorBlock != nil {
        continue
      }

      plans.append(
        PropertyPlan(
          name: pattern.identifier.text,
          typeName: trimmed(typeAnnotation.type.description),
          isMutable: variable.bindingSpecifier.tokenKind == .keyword(.var),
          decoderOverride: overrides.decoder,
          encoderOverride: overrides.encoder
        ))
    }
  }

  return plans
}

private func collectExportedMethods(from members: MemberBlockItemListSyntax)
  throws(MacroUsageError) -> [MethodPlan]
{
  var plans: [MethodPlan] = []

  for member in members {
    guard let function = member.decl.as(FunctionDeclSyntax.self) else {
      continue
    }

    guard let export = try parseMethodExportSpec(from: function.attributes) else {
      continue
    }

    if function.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) {
      throw MacroUsageError(description: "@JSClassFunction supports instance methods only")
    }
    if function.genericParameterClause != nil {
      throw MacroUsageError(description: "@JSClassFunction does not support generic methods")
    }
    if function.signature.effectSpecifiers?.asyncSpecifier != nil {
      throw MacroUsageError(description: "@JSClassFunction does not support async methods")
    }

    var parameters: [MethodParameterPlan] = []
    parameters.reserveCapacity(function.signature.parameterClause.parameters.count)
    for (index, parameter) in function.signature.parameterClause.parameters.enumerated() {
      let firstName = parameter.firstName.text
      let secondName = parameter.secondName?.text
      let localName = secondName ?? firstName
      let externalName = firstName == "_" ? nil : firstName
      let overrideDecoder: String?
      if let argumentDecoders = export.argumentDecoders,
        argumentDecoders.indices.contains(index)
      {
        overrideDecoder = argumentDecoders[index]
      } else {
        overrideDecoder = nil
      }

      if parameter.ellipsis != nil {
        throw MacroUsageError(description: "@JSClassFunction does not support variadic parameters")
      }

      parameters.append(
        MethodParameterPlan(
          externalName: externalName,
          localName: localName,
          typeName: trimmed(parameter.type.description),
          decoderOverride: overrideDecoder
        ))
    }

    if let argumentDecoders = export.argumentDecoders,
      argumentDecoders.count != parameters.count
    {
      throw MacroUsageError(
        description:
          "@JSClassFunctionArguments count must match the number of method parameters"
      )
    }

    let isThrowing = function.signature.effectSpecifiers?.throwsClause != nil
    if export.errorEncoder != nil && !isThrowing {
      throw MacroUsageError(
        description: "@JSClassFunctionError can only be used on throwing methods"
      )
    }

    plans.append(
      MethodPlan(
        swiftName: function.name.text,
        jsName: export.jsName ?? function.name.text,
        parameters: parameters,
        returnTypeName: function.signature.returnClause.map { trimmed($0.type.description) },
        returnEncoder: export.returnEncoder,
        errorEncoder: export.errorEncoder,
        isThrowing: isThrowing
      )
    )
  }

  return plans
}

private func indent(_ source: String, by prefix: String) -> String {
  source.split(separator: "\n", omittingEmptySubsequences: false)
    .map { line in
      line.isEmpty ? String(line) : prefix + line
    }
    .joined(separator: "\n")
}

private func makeMethodCallbackBody(_ method: MethodPlan, indentLevel: String) -> String {
  let decodeLines = method.parameters.enumerated().map { index, parameter in
    let decoder = parameter.decoderOverride ?? "JSDefaultConverter<\(parameter.typeName)>"
    return
      "let __arg\(index) = try arguments.tryUnpack(at: \(index), using: \(decoder).self, in: context)"
  }.joined(separator: "\n")

  let callArguments = method.parameters.enumerated().map { index, parameter in
    if let externalName = parameter.externalName {
      return "\(externalName): __arg\(index)"
    }
    return "__arg\(index)"
  }.joined(separator: ", ")

  let callExpression = "instance.\(method.swiftName)(\(callArguments))"
  let invokedCallExpression = method.isThrowing ? "try \(callExpression)" : callExpression

  var bodyLines: [String] = []
  if !decodeLines.isEmpty {
    bodyLines.append(decodeLines)
  }

  if let returnTypeName = method.returnTypeName, returnTypeName != "Void", returnTypeName != "()" {
    if let returnEncoder = method.returnEncoder {
      bodyLines.append("let __result = \(invokedCallExpression)")
      bodyLines.append(
        "let __encoded = try \(returnEncoder).tryEncode(__result, in: context)")
      bodyLines.append("return .value(__encoded)")
    } else {
      bodyLines.append("let __result = \(invokedCallExpression)")
      bodyLines.append("let __encoded = try __result.tryEncode(in: context)")
      bodyLines.append("return .value(__encoded)")
    }
  } else {
    bodyLines.append("\(invokedCallExpression)")
    bodyLines.append(
      "return .value(SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context))")
  }

  let executionSource: String
  if method.isThrowing, let errorEncoder = method.errorEncoder {
    executionSource =
      (["do {"] + bodyLines + [
        "} catch let error as \(errorEncoder).SwiftType {",
        "  if let encoded = try? \(errorEncoder).tryEncode(error, in: context) {",
        "    return .exception(encoded)",
        "  }",
        "  return .exception(SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context))",
        "} catch {",
        "  return .exception(SwiftJavaScript.JSValue<JavaScriptCoreEngine>(string: \"\\(error)\", in: context))",
        "}",
      ]).joined(separator: "\n")
  } else if method.isThrowing {
    executionSource =
      (["do {"] + bodyLines + [
        "} catch {",
        "  return .exception(SwiftJavaScript.JSValue<JavaScriptCoreEngine>(string: \"\\(error)\", in: context))",
        "}",
      ]).joined(separator: "\n")
  } else {
    executionSource =
      (["do {"] + bodyLines + [
        "} catch {",
        "  return .exception(SwiftJavaScript.JSValue<JavaScriptCoreEngine>(string: \"\\(error)\", in: context))",
        "}",
      ]).joined(separator: "\n")
  }

  return indent(executionSource, by: indentLevel)
}

private func makeMethodFunctionCase(_ method: MethodPlan) -> String {
  let callbackBody = makeMethodCallbackBody(method, indentLevel: "                ")
  let argumentCount = method.parameters.count

  return [
    "            SwiftJavaScript.JSStaticFunction<JavaScriptCoreEngine>(",
    "              name: \"\(method.jsName)\",",
    "              attributes: .none,",
    "              callAsFunction: { context, this, arguments in",
    "                guard let instance = try? Self.tryDecode(this, in: context) else {",
    "                  return .exception(",
    "                    SwiftJavaScript.JSValue<JavaScriptCoreEngine>(string: \"failed to decode \\\\(Self.self) backing instance\", in: context)",
    "                  )",
    "                }",
    "                guard arguments.count == \(argumentCount) else {",
    "                  return .value(SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context))",
    "                }",
    callbackBody,
    "              }",
    "            )",
  ].joined(separator: "\n")
}

private func makeMethodGetPropertyCase(_ method: MethodPlan) -> String {
  let callbackBody = makeMethodCallbackBody(method, indentLevel: "                  ")
  return [
    "            case \"\(method.jsName)\":",
    "              return .value(",
    "                context.makeFunction(named: \"\(method.jsName)\") { context, this, arguments in",
    "                  guard let instance = try? Self.tryDecode(this, in: context) else {",
    "                    return .exception(",
    "                      SwiftJavaScript.JSValue<JavaScriptCoreEngine>(string: \"failed to decode \\\\(Self.self) backing instance\", in: context)",
    "                    )",
    "                  }",
    "                  guard arguments.count == \(method.parameters.count) else {",
    "                    return .value(SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context))",
    "                  }",
    callbackBody,
    "                }",
    "              )",
  ].joined(separator: "\n")
}

private func inheritedClassName(from decl: ClassDeclSyntax) -> String? {
  guard let inheritanceClause = decl.inheritanceClause,
    let inheritedType = inheritanceClause.inheritedTypes.first
  else {
    return nil
  }

  return trimmed(inheritedType.type.description)
}

private func enumRawValueTypeName(from decl: EnumDeclSyntax) -> String? {
  guard let inheritanceClause = decl.inheritanceClause,
    let inheritedType = inheritanceClause.inheritedTypes.first
  else {
    return nil
  }

  let typeName = trimmed(inheritedType.type.description)
  switch typeName {
  case "String", "Character", "Int", "Int8", "Int16", "Int32", "Int64", "UInt",
    "UInt8", "UInt16", "UInt32", "UInt64", "Float", "Double":
    return typeName
  default:
    return nil
  }
}

private func isFinalClass(_ decl: ClassDeclSyntax) -> Bool {
  decl.modifiers.contains(where: { $0.name.tokenKind == .keyword(.final) })
}

private struct EnumCasePlan {
  let name: String
  let associatedValues: [EnumAssociatedValuePlan]

  var hasAssociatedValues: Bool {
    !associatedValues.isEmpty
  }

  var payloadKind: EnumPayloadKind {
    if associatedValues.isEmpty {
      return .none
    }

    let labeledCount = associatedValues.count(where: { $0.label != nil })
    if labeledCount == 0 {
      return associatedValues.count == 1 ? .singleUnlabeled : .multipleUnlabeled
    }
    if labeledCount == associatedValues.count {
      return .labeledObject
    }
    return .invalidMixed
  }
}

private struct EnumAssociatedValuePlan {
  let label: String?
  let typeName: String
  let decoderOverride: String?
  let encoderOverride: String?
}

private enum EnumPayloadKind {
  case none
  case singleUnlabeled
  case multipleUnlabeled
  case labeledObject
  case invalidMixed
}

private func collectEnumCases(
  from members: MemberBlockItemListSyntax,
  fieldOverrides: [String: FieldOverrideSpec] = [:]
) throws(MacroUsageError)
  -> [EnumCasePlan]
{
  var plans: [EnumCasePlan] = []
  var unmatchedFieldOverrides = fieldOverrides

  for member in members {
    guard let enumCase = member.decl.as(EnumCaseDeclSyntax.self) else {
      continue
    }

    for element in enumCase.elements {
      var associatedValues: [EnumAssociatedValuePlan] = []
      let associatedValueCount = element.parameterClause?.parameters.count ?? 0
      if let parameterClause = element.parameterClause {
        associatedValues.reserveCapacity(parameterClause.parameters.count)
        for (index, parameter) in parameterClause.parameters.enumerated() {
          let firstName = parameter.firstName?.text
          let secondName = parameter.secondName?.text
          let label: String?
          if let secondName {
            label = secondName == "_" ? nil : secondName
          } else if let firstName {
            label = firstName == "_" ? nil : firstName
          } else {
            label = nil
          }

          let caseName = element.name.text
          let selector = label ?? String(index)
          let scopedSelector = "\(caseName).\(selector)"
          let override: FieldOverrideSpec?
          if let explicit = unmatchedFieldOverrides.removeValue(forKey: scopedSelector) {
            override = explicit
          } else if associatedValueCount == 1,
            let implicit = unmatchedFieldOverrides.removeValue(forKey: caseName)
          {
            override = implicit
          } else {
            override = nil
          }

          associatedValues.append(
            EnumAssociatedValuePlan(
              label: label,
              typeName: trimmed(parameter.type.description),
              decoderOverride: override?.decoder,
              encoderOverride: override?.encoder
            ))
        }
      }

      let plan = EnumCasePlan(name: element.name.text, associatedValues: associatedValues)
      if case .invalidMixed = plan.payloadKind {
        throw MacroUsageError(
          description:
            "@JSValueAutoSerialization does not support enum cases that mix labeled and unlabeled associated values"
        )
      }

      plans.append(plan)
    }
  }

  if let unknownSelector = unmatchedFieldOverrides.keys.sorted().first {
    throw MacroUsageError(
      description:
        "@JSValueFieldCoding selector \"\(unknownSelector)\" does not match any associated value"
    )
  }

  return plans
}

private func makeEnumDecodeCase(
  _ enumCase: EnumCasePlan,
  typeName: String,
  flattenedLabeledPayload: Bool
) -> String {
  switch enumCase.payloadKind {
  case .none:
    return "case \"\(enumCase.name)\": return .\(enumCase.name)"
  case .singleUnlabeled:
    let associatedValue = enumCase.associatedValues[0]
    let decodeExpression: String
    if let decoder = associatedValue.decoderOverride {
      decodeExpression = "try \(decoder).tryDecode(__payload, in: context)"
    } else {
      decodeExpression = "try \(associatedValue.typeName).tryDecode(__payload, in: context)"
    }
    return """
       case "\(enumCase.name)":
         let __payload = value.getProperty(forKey: __payloadKey, in: context)
         return .\(enumCase.name)(\(decodeExpression))
      """
  case .multipleUnlabeled:
    var lines: [String] = [
      "case \"\(enumCase.name)\":",
      "  let __payload = value.getProperty(forKey: __payloadKey, in: context)",
      "  guard __payload.isArray(in: context) else {",
      "    throw .typeMismatch(expected: \"array\", actual: __payload.type(in: context))",
      "  }",
    ]
    var arguments: [String] = []
    for (index, associatedValue) in enumCase.associatedValues.enumerated() {
      let localName = "__payload_\(enumCase.name)_\(index)"
      lines.append("  let \(localName) = __payload.getProperty(at: \(index), in: context)")
      if let decoder = associatedValue.decoderOverride {
        arguments.append("try \(decoder).tryDecode(\(localName), in: context)")
      } else {
        arguments.append("try \(associatedValue.typeName).tryDecode(\(localName), in: context)")
      }
    }
    lines.append("  return .\(enumCase.name)(\(arguments.joined(separator: ", ")))")
    return lines.joined(separator: "\n")
  case .labeledObject:
    var lines: [String] = [
      "case \"\(enumCase.name)\":"
    ]
    if flattenedLabeledPayload {
    } else {
      lines.append("  let __payload = value.getProperty(forKey: __payloadKey, in: context)")
      lines.append("  guard __payload.isObject(in: context) else {")
      lines.append(
        "    throw .typeMismatch(expected: \"object\", actual: __payload.type(in: context))")
      lines.append("  }")
    }
    let payloadSource = flattenedLabeledPayload ? "value" : "__payload"
    var arguments: [String] = []
    for associatedValue in enumCase.associatedValues {
      let label = associatedValue.label!
      let keyName = "__payloadKey_\(enumCase.name)_\(label)"
      let valueName = "__payloadValue_\(enumCase.name)_\(label)"
      lines.append(
        "  let \(keyName): Swift.StaticString = \"\(label)\"")
      lines.append(
        "  let \(valueName) = \(payloadSource).getProperty(forKey: \(keyName), in: context)")
      if let decoder = associatedValue.decoderOverride {
        arguments.append("\(label): try \(decoder).tryDecode(\(valueName), in: context)")
      } else {
        arguments.append(
          "\(label): try \(associatedValue.typeName).tryDecode(\(valueName), in: context)")
      }
    }
    lines.append("  return .\(enumCase.name)(\(arguments.joined(separator: ", ")))")
    return lines.joined(separator: "\n")
  case .invalidMixed:
    return ""
  }
}

private func makeEnumEncodeCase(
  _ enumCase: EnumCasePlan,
  taggedObjectMode: Bool,
  flattenedLabeledPayload: Bool
) -> String {
  switch enumCase.payloadKind {
  case .none:
    if taggedObjectMode {
      return """
        case .\(enumCase.name):
          let __object = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(objectIn: context)
          __object.setProperty("\(enumCase.name)", forKey: __tagKey, in: context)
          return __object
        """
    }
    return
      "case .\(enumCase.name): return SwiftJavaScript.JSValue<JavaScriptCoreEngine>(string: \"\(enumCase.name)\", in: context)"
  case .singleUnlabeled:
    let associatedValue = enumCase.associatedValues[0]
    let binding = associatedValue.label ?? "associated0"
    let encodeExpression: String
    if let encoder = associatedValue.encoderOverride {
      encodeExpression = "try \(encoder).tryEncode(\(binding), in: context)"
    } else {
      encodeExpression = "try \(binding).tryEncode(in: context)"
    }
    return """
      case .\(enumCase.name)(let \(binding)):
        let __object = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(objectIn: context)
        __object.setProperty("\(enumCase.name)", forKey: __tagKey, in: context)
        let __payload = \(encodeExpression)
        __object.setProperty(__payload, forKey: __payloadKey, in: context)
        return __object
      """
  case .multipleUnlabeled:
    let bindings = enumCase.associatedValues.enumerated().map { index, _ in "associated\(index)" }
    let pattern = bindings.map { "let \($0)" }.joined(separator: ", ")
    var lines: [String] = [
      "case .\(enumCase.name)(\(pattern)):",
      "  let __object = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(objectIn: context)",
      "  __object.setProperty(\"\(enumCase.name)\", forKey: __tagKey, in: context)",
      "  let __payload = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(arrayIn: context)",
    ]
    for (index, binding) in bindings.enumerated() {
      if let encoder = enumCase.associatedValues[index].encoderOverride {
        lines.append("  let __encoded_\(index) = try \(encoder).tryEncode(\(binding), in: context)")
      } else {
        lines.append("  let __encoded_\(index) = try \(binding).tryEncode(in: context)")
      }
      lines.append("  __payload.setProperty(__encoded_\(index), at: \(index), in: context)")
    }
    lines.append("  __object.setProperty(__payload, forKey: __payloadKey, in: context)")
    lines.append("  return __object")
    return lines.joined(separator: "\n")
  case .labeledObject:
    let bindings = enumCase.associatedValues.map { $0.label! }
    let pattern = bindings.map { "\($0): let \($0)" }.joined(separator: ", ")
    var lines: [String] = [
      "case .\(enumCase.name)(\(pattern)):",
      "  let __object = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(objectIn: context)",
      "  __object.setProperty(\"\(enumCase.name)\", forKey: __tagKey, in: context)",
    ]
    if flattenedLabeledPayload {
    } else {
      lines.append(
        "  let __payload = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(objectIn: context)")
    }
    let payloadTarget = flattenedLabeledPayload ? "__object" : "__payload"
    for (index, label) in bindings.enumerated() {
      lines.append(
        "  let __payloadKey_\(label): Swift.StaticString = \"\(label)\""
      )
      if let encoder = enumCase.associatedValues[index].encoderOverride {
        lines.append("  let __encoded_\(label) = try \(encoder).tryEncode(\(label), in: context)")
      } else {
        lines.append("  let __encoded_\(label) = try \(label).tryEncode(in: context)")
      }
      lines.append(
        "  \(payloadTarget).setProperty(__encoded_\(label), forKey: __payloadKey_\(label), in: context)"
      )
    }
    if !flattenedLabeledPayload {
      lines.append("  __object.setProperty(__payload, forKey: __payloadKey, in: context)")
    }
    lines.append("  return __object")
    return lines.joined(separator: "\n")
  case .invalidMixed:
    return ""
  }
}

public struct JSValueAutoSerializationMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo _: [TypeSyntax],
    in _: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let typeName = trimmed(type.description)
    let options = try parseAutoSerializationOptions(from: node)
    let arguments = options.typeArguments

    let sharedDecoder: String?
    let sharedEncoder: String?
    switch arguments.count {
    case 0:
      sharedDecoder = nil
      sharedEncoder = nil
    case 1:
      sharedDecoder = arguments[0]
      sharedEncoder = arguments[0]
    case 2:
      sharedDecoder = arguments[0]
      sharedEncoder = arguments[1]
    default:
      throw MacroUsageError(
        description: "@JSValueAutoSerialization accepts 0, 1 or 2 type arguments")
    }

    let decodeBody: String
    let encodeBody: String
    let initSource: String

    if let decoder = sharedDecoder, let encoder = sharedEncoder {
      decodeBody = """
        return try \(decoder).tryDecode(value, in: context)
        """
      encodeBody = """
        return try \(encoder).tryEncode(self, in: context)
        """
      initSource = """
        public init(value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>, in context: borrowing JSInstantContext<JavaScriptCoreEngine>) {
          do {
            self = try Self.tryDecode(value, in: context)
          } catch {
            fatalError("\(typeName).init(value:in:) failed: \\(error)")
          }
        }
        """
    } else if let structDecl = declaration.as(StructDeclSyntax.self) {
      let properties = collectStoredProperties(from: structDecl.memberBlock.members)

      var decodeLines: [String] = [
        "guard value.isObject(in: context) else {",
        "  throw .typeMismatch(expected: \"object\", actual: value.type(in: context))",
        "}",
      ]

      var initArgs: [String] = []
      for property in properties {
        let keyName = "__key_\(property.name)"
        let localName = "__\(property.name)Value"
        decodeLines.append(
          "let \(keyName): Swift.StaticString = \"\(property.name)\""
        )
        decodeLines.append(
          "let \(localName) = value.getProperty(forKey: \(keyName), in: context)")

        if let decoder = property.decoderOverride ?? sharedDecoder {
          initArgs.append("\(property.name): try \(decoder).tryDecode(\(localName), in: context)")
        } else {
          initArgs.append(
            "\(property.name): try \(property.typeName).tryDecode(\(localName), in: context)")
        }
      }
      decodeLines.append("return Self(\(initArgs.joined(separator: ", ")))")
      decodeBody = decodeLines.joined(separator: "\n")

      var encodeLines: [String] = [
        "let object = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(objectIn: context)"
      ]
      for property in properties {
        let keyName = "__key_\(property.name)"
        let encodedName = "__encoded_\(property.name)"
        encodeLines.append(
          "let \(keyName): Swift.StaticString = \"\(property.name)\""
        )
        if let encoder = property.encoderOverride ?? sharedEncoder {
          encodeLines.append(
            "let \(encodedName) = try \(encoder).tryEncode(self.\(property.name), in: context)")
        } else {
          encodeLines.append(
            "let \(encodedName) = try self.\(property.name).tryEncode(in: context)")
        }
        encodeLines.append(
          "object.setProperty(\(encodedName), forKey: \(keyName), in: context)")
      }
      encodeLines.append("return object")
      encodeBody = encodeLines.joined(separator: "\n")
      initSource = """
        public init(value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>, in context: borrowing JSInstantContext<JavaScriptCoreEngine>) {
          do {
            self = try Self.tryDecode(value, in: context)
          } catch {
            fatalError("\(typeName).init(value:in:) failed: \\(error)")
          }
        }
        """
    } else if let classDecl = declaration.as(ClassDeclSyntax.self) {
      guard isFinalClass(classDecl) else {
        throw MacroUsageError(
          description:
            "@JSValueAutoSerialization automatic class synthesis currently supports final class only"
        )
      }

      let properties = collectStoredProperties(from: classDecl.memberBlock.members)

      var decodeLines: [String] = [
        "guard value.isObject(in: context) else {",
        "  throw .typeMismatch(expected: \"object\", actual: value.type(in: context))",
        "}",
      ]

      var initArgs: [String] = []
      for property in properties {
        let keyName = "__key_\(property.name)"
        let localName = "__\(property.name)Value"
        decodeLines.append(
          "let \(keyName): Swift.StaticString = \"\(property.name)\""
        )
        decodeLines.append(
          "let \(localName) = value.getProperty(forKey: \(keyName), in: context)")

        if let decoder = property.decoderOverride ?? sharedDecoder {
          initArgs.append("\(property.name): try \(decoder).tryDecode(\(localName), in: context)")
        } else {
          initArgs.append(
            "\(property.name): try \(property.typeName).tryDecode(\(localName), in: context)")
        }
      }

      decodeLines.append("return Self(\(initArgs.joined(separator: ", ")))")
      decodeBody = decodeLines.joined(separator: "\n")

      let initForwardArgs = properties.map { "\($0.name): __decoded.\($0.name)" }
        .joined(separator: ", ")
      initSource = """
        public convenience init(value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>, in context: borrowing JSInstantContext<JavaScriptCoreEngine>) {
          do {
            let __decoded = try Self.tryDecode(value, in: context)
            self.init(\(initForwardArgs))
          } catch {
            fatalError("\(typeName).init(value:in:) failed: \\(error)")
          }
        }
        """

      var encodeLines: [String] = [
        "let object = SwiftJavaScript.JSValue<JavaScriptCoreEngine>(objectIn: context)"
      ]
      for property in properties {
        let keyName = "__key_\(property.name)"
        let encodedName = "__encoded_\(property.name)"
        encodeLines.append(
          "let \(keyName): Swift.StaticString = \"\(property.name)\""
        )
        if let encoder = property.encoderOverride ?? sharedEncoder {
          encodeLines.append(
            "let \(encodedName) = try \(encoder).tryEncode(self.\(property.name), in: context)")
        } else {
          encodeLines.append(
            "let \(encodedName) = try self.\(property.name).tryEncode(in: context)")
        }
        encodeLines.append(
          "object.setProperty(\(encodedName), forKey: \(keyName), in: context)")
      }
      encodeLines.append("return object")
      encodeBody = encodeLines.joined(separator: "\n")
    } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
      let enumFieldOverrides = try parseEnumFieldOverrides(from: enumDecl.attributes)
      let cases = try collectEnumCases(
        from: enumDecl.memberBlock.members,
        fieldOverrides: enumFieldOverrides
      )
      let rawValueTypeName = enumRawValueTypeName(from: enumDecl)
      initSource = """
        public init(value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>, in context: borrowing JSInstantContext<JavaScriptCoreEngine>) {
          do {
            self = try Self.tryDecode(value, in: context)
          } catch {
            fatalError("\(typeName).init(value:in:) failed: \\(error)")
          }
        }
        """
      guard !cases.isEmpty else {
        throw MacroUsageError(
          description: "@JSValueAutoSerialization requires at least one enum case")
      }

      let hasAssociatedValues = cases.contains(where: { $0.hasAssociatedValues })

      if hasAssociatedValues {
        let canFlattenLabeledPayload = cases.allSatisfy {
          switch $0.payloadKind {
          case .none, .labeledObject:
            return true
          case .singleUnlabeled, .multipleUnlabeled, .invalidMixed:
            return false
          }
        }
        let flattenedLabeledPayload =
          if options.isPayloadKeyExplicit {
            options.payloadKey.isEmpty
          } else {
            canFlattenLabeledPayload
          }
        if flattenedLabeledPayload && !canFlattenLabeledPayload {
          throw MacroUsageError(
            description:
              "@JSValueAutoSerialization payloadKey cannot be empty unless every associated-value case uses labeled payload fields"
          )
        }

        let decodeCases = cases.map {
          makeEnumDecodeCase(
            $0,
            typeName: typeName,
            flattenedLabeledPayload: flattenedLabeledPayload
          )
        }
        .joined(separator: "\n")
        let encodeCases = cases.map {
          makeEnumEncodeCase(
            $0,
            taggedObjectMode: true,
            flattenedLabeledPayload: flattenedLabeledPayload
          )
        }
        .joined(separator: "\n")

        let payloadKeyDeclaration =
          if flattenedLabeledPayload {
            ""
          } else {
            "let __payloadKey: Swift.StaticString = \"\(options.payloadKey)\""
          }

        decodeBody = """
          guard value.isObject(in: context) else {
            throw .typeMismatch(expected: "object", actual: value.type(in: context))
          }
          let __tagKey: Swift.StaticString = "\(options.tagKey)"
          \(payloadKeyDeclaration)
          let __tagValue = value.getProperty(forKey: __tagKey, in: context)
          let __caseName = try String.tryDecode(__tagValue, in: context)
          switch __caseName {
          \(decodeCases)
          default:
            throw .codable("\(typeName) does not contain case \\(__caseName)")
          }
          """
        encodeBody = """
          let __tagKey: Swift.StaticString = "\(options.tagKey)"
          \(payloadKeyDeclaration)
          switch self {
          \(encodeCases)
          }
          """
      } else {
        if let rawValueTypeName {
          decodeBody = """
            let rawValue = try \(rawValueTypeName).tryDecode(value, in: context)
            guard let decoded = Self(rawValue: rawValue) else {
              throw .codable("\(typeName) does not contain rawValue \\(rawValue)")
            }
            return decoded
            """
          encodeBody = """
            return try self.rawValue.tryEncode(in: context)
            """
        } else {
          let switchCases = cases.map { enumCase in
            "case \"\(enumCase.name)\": return .\(enumCase.name)"
          }.joined(separator: "\n")

          let encodeCases = cases.map { enumCase in
            "case .\(enumCase.name): return SwiftJavaScript.JSValue<JavaScriptCoreEngine>(string: \"\(enumCase.name)\", in: context)"
          }.joined(separator: "\n")

          decodeBody = """
            let caseName = try String.tryDecode(value, in: context)
            switch caseName {
            \(switchCases)
            default:
              throw .codable("\(typeName) does not contain case \\(caseName)")
            }
            """
          encodeBody = """
            switch self {
            \(encodeCases)
            }
            """
        }
      }
    } else {
      throw MacroUsageError(
        description:
          "@JSValueAutoSerialization currently supports struct, enum without associated values, or explicit converter arguments"
      )
    }

    let genericInitSource: String
    if declaration.as(ClassDeclSyntax.self) != nil {
      genericInitSource = """
          public convenience init<E: JSValueConversionEngine>(
            value: borrowing JSValue<E>,
            in context: borrowing JSInstantContext<E>
          ) {
            precondition(
              E.self == JavaScriptCoreEngine.self,
              "This conversion path only supports JavaScriptCoreEngine"
            )
           self.init(
             value: JSValue<JavaScriptCoreEngine>(
                handleValue: unsafeBitCast(value.borrowHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self),
                in: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
             ),
             in: JSInstantContext<JavaScriptCoreEngine>(
               handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
             )
          )
        }
        """
    } else {
      genericInitSource = """
        public init<E: JSValueConversionEngine>(
           value: borrowing JSValue<E>,
           in context: borrowing JSInstantContext<E>
         ) {
           precondition(
             E.self == JavaScriptCoreEngine.self,
             "This conversion path only supports JavaScriptCoreEngine"
           )
           self.init(
             value: JSValue<JavaScriptCoreEngine>(
                handleValue: unsafeBitCast(value.borrowHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self),
                in: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
             ),
             in: JSInstantContext<JavaScriptCoreEngine>(
               handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
             )
          )
        }
        """
    }

    let extSource = """
      extension \(typeName): JSValueCodable {
        \(genericInitSource)

        public static func tryDecode<E: JSValueConversionEngine>(
          _ value: borrowing JSValue<E>,
          in context: borrowing JSInstantContext<E>
        ) throws(JSValueConversionError) -> Self {
          precondition(
            E.self == JavaScriptCoreEngine.self,
            "This conversion path only supports JavaScriptCoreEngine"
          )
          return try Self.tryDecode(
            JSValue<JavaScriptCoreEngine>(
               handleValue: unsafeBitCast(value.borrowHandle(), to: JSValueHandle<JavaScriptCoreEngine>.self),
               in: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
            ),
            in: JSInstantContext<JavaScriptCoreEngine>(
              handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
            )
          )
        }

        public func toJSValue<E: JSValueConversionEngine>(
          in context: borrowing JSInstantContext<E>
        ) -> JSValue<E> {
          precondition(
            E.self == JavaScriptCoreEngine.self,
            "This conversion path only supports JavaScriptCoreEngine"
          )
          let __encoded = self.toJSValue(
            in: JSInstantContext<JavaScriptCoreEngine>(
              handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
            )
          )
          return JSValue<E>(
             handleValue: unsafeBitCast(__encoded.borrowHandle(), to: JSValueHandle<E>.self),
             in: context.driverContextHandle
          )
        }

        public func tryEncode<E: JSValueConversionEngine>(
          in context: borrowing JSInstantContext<E>
        ) throws(JSValueConversionError) -> JSValue<E> {
          precondition(
            E.self == JavaScriptCoreEngine.self,
            "This conversion path only supports JavaScriptCoreEngine"
          )
          let __encoded = try self.tryEncode(
            in: JSInstantContext<JavaScriptCoreEngine>(
              handle: unsafeBitCast(context.driverContextHandle, to: JavaScriptCoreContextHandle.self)
            )
          )
          return JSValue<E>(
             handleValue: unsafeBitCast(__encoded.borrowHandle(), to: JSValueHandle<E>.self),
             in: context.driverContextHandle
          )
        }

         \(initSource)

         public static func tryDecode(
           _ value: borrowing SwiftJavaScript.JSValue<JavaScriptCoreEngine>,
           in context: borrowing JSInstantContext<JavaScriptCoreEngine>
         ) throws(JSValueConversionError) -> Self {
           \(decodeBody)
         }

         public func toJSValue(in context: borrowing JSInstantContext<JavaScriptCoreEngine>) -> SwiftJavaScript.JSValue<JavaScriptCoreEngine> {
           do {
             return try self.tryEncode(in: context)
           } catch {
             return SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context)
           }
         }

         public func tryEncode(
           in context: borrowing JSInstantContext<JavaScriptCoreEngine>
        ) throws(JSValueConversionError) -> SwiftJavaScript.JSValue<JavaScriptCoreEngine> {
          \(encodeBody)
        }
      }
      """

    let extDecl = DeclSyntax(stringLiteral: extSource)
    guard let ext = extDecl.as(ExtensionDeclSyntax.self) else {
      throw MacroUsageError(description: "failed to build extension for \(typeName)")
    }

    return [ext]
  }
}

public struct JSClassAutoConvertibleMacro: MemberMacro, ExtensionMacro {
  public static func expansion(
    of _: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in _: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
      throw MacroUsageError(description: "@JSClassAutoConvertible supports class only")
    }

    let properties = collectStoredProperties(from: classDecl.memberBlock.members)
    let methods = try collectExportedMethods(from: classDecl.memberBlock.members)
    let inheritedClass = inheritedClassName(from: classDecl)

    let declarationModifier = inheritedClass == nil ? "public class" : "public override class"

    let parentClassSetup: String
    let parentHasPropertyFallback: String
    let parentGetPropertyFallback: String
    let parentSetPropertyFallback: String

    if let inheritedClass {
      parentClassSetup = """
        definition.parentClass = SwiftJavaScript.JSClassParentDescriptor<JavaScriptCoreEngine, JSPropertyNameAccumulatorRef>.for(\(inheritedClass).self)
        """
      parentHasPropertyFallback = """
              return \(inheritedClass).jsClassDefinition.hasProperty?(context, this, property) ?? false
        """
      parentGetPropertyFallback = """
              return \(inheritedClass).jsClassDefinition.getProperty?(context, this, property)
                ?? .value(SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context))
        """
      parentSetPropertyFallback = """
              return \(inheritedClass).jsClassDefinition.setProperty?(context, this, property, value)
        """
    } else {
      parentClassSetup = ""
      parentHasPropertyFallback = "              return false"
      parentGetPropertyFallback =
        "              return .value(SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context))"
      parentSetPropertyFallback = "              return nil"
    }

    let hasPropertyCases =
      properties.map { "case \"\($0.name)\": return true" }
      .joined(separator: "\n")

    let getPropertyCases = properties.map { property in
      let encodeLine: String
      if let encoder = property.encoderOverride {
        encodeLine =
          "return .value((try? \(encoder).tryEncode(instance.\(property.name), in: context)) ?? SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context))"
      } else {
        encodeLine =
          "return .value((try? instance.\(property.name).tryEncode(in: context)) ?? SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context))"
      }

      return """
            case \"\(property.name)\":
              \(encodeLine)
        """
    }.joined(separator: "\n")

    let methodGetPropertyCases = methods.map(makeMethodGetPropertyCase).joined(separator: "\n")

    let setPropertyCases = properties.map { property in
      if !property.isMutable {
        return """
            case \"\(property.name)\":
              return nil
          """
      }

      let decodeLine: String
      if let decoder = property.decoderOverride {
        decodeLine = "instance.\(property.name) = try \(decoder).tryDecode(value, in: context)"
      } else {
        decodeLine =
          "instance.\(property.name) = try \(property.typeName).tryDecode(value, in: context)"
      }

      return """
          case \"\(property.name)\":
            do {
              \(decodeLine)
              return nil
            } catch {
              return SwiftJavaScript.JSValue<JavaScriptCoreEngine>(string: "\\(error)", in: context)
            }
        """
    }.joined(separator: "\n")

    let staticFunctionsSource: String
    if methods.isEmpty {
      staticFunctionsSource = ""
    } else {
      let staticFunctionCases = methods.map(makeMethodFunctionCase).joined(separator: ",\n")
      staticFunctionsSource = """
          definition.staticFunctions = [
          \(staticFunctionCases)
          ]
        """
    }

    let propertySource = """
      \(declarationModifier) var jsClassDefinition: SwiftJavaScript.JSEngineClassDefinition<JavaScriptCoreEngine, SwiftJavaScript.JSClassParentDescriptor<JavaScriptCoreEngine, JSPropertyNameAccumulatorRef>, JSPropertyNameAccumulatorRef> {
        var definition = SwiftJavaScript.JSEngineClassDefinition<JavaScriptCoreEngine, SwiftJavaScript.JSClassParentDescriptor<JavaScriptCoreEngine, JSPropertyNameAccumulatorRef>, JSPropertyNameAccumulatorRef>()
        definition.className = \"\(trimmed(classDecl.name.text))\"
        \(parentClassSetup)
        \(staticFunctionsSource)
        definition.hasProperty = { context, this, property in
          switch property {
          \(hasPropertyCases)
          default:
        \(parentHasPropertyFallback)
          }
        }
        definition.getProperty = { context, this, property in
          guard let instance = try? Self.tryDecode(this, in: context) else {
            return .value(SwiftJavaScript.JSValue<JavaScriptCoreEngine>(undefinedIn: context))
          }
          switch property {
          \(getPropertyCases)
          \(methodGetPropertyCases)
          default:
        \(parentGetPropertyFallback)
          }
        }
        definition.setProperty = { context, this, property, value in
          guard let instance = try? Self.tryDecode(this, in: context) else {
            return SwiftJavaScript.JSValue<JavaScriptCoreEngine>(string: \"failed to decode \\(Self.self) backing instance\", in: context)
          }
          switch property {
          \(setPropertyCases)
          default:
        \(parentSetPropertyFallback)
          }
        }
        return definition
      }
      """

    return [DeclSyntax(stringLiteral: propertySource)]
  }

  public static func expansion(
    of _: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo _: [TypeSyntax],
    in _: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard let classDecl = declaration.as(ClassDeclSyntax.self) else {
      throw MacroUsageError(description: "@JSClassAutoConvertible supports class only")
    }

    guard inheritedClassName(from: classDecl) == nil else {
      return []
    }

    let extSource = """
      extension \(trimmed(type.description)): JSClassValueConvertible {}
      """

    let extDecl = DeclSyntax(stringLiteral: extSource)
    guard let ext = extDecl.as(ExtensionDeclSyntax.self) else {
      throw MacroUsageError(
        description: "failed to build JSClass extension for \(trimmed(type.description))")
    }

    return [ext]
  }
}

public struct JSValueFieldMarkerMacro: PeerMacro {
  public static func expansion(
    of _: AttributeSyntax,
    providingPeersOf _: some DeclSyntaxProtocol,
    in _: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    []
  }
}

@main
struct SwiftyJavaScriptCoreMacrosPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    JSValueAutoSerializationMacro.self,
    JSClassAutoConvertibleMacro.self,
    JSValueFieldMarkerMacro.self,
  ]
}
