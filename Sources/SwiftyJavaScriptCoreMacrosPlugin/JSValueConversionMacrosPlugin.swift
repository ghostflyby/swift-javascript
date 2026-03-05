import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

private struct MacroUsageError: Error, CustomStringConvertible {
  let description: String
}

private struct PropertyPlan {
  let name: String
  let typeName: String
  let decoderOverride: String?
  let encoderOverride: String?
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

private func parseTypeArguments(from node: AttributeSyntax) -> [String] {
  guard let arguments = node.arguments,
    case .argumentList(let list) = arguments
  else {
    return []
  }
  return list.map { stripDotSelf($0.expression.description) }
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
      let nameSyntax = attribute.attributeName.as(IdentifierTypeSyntax.self)
    else {
      continue
    }

    let name = nameSyntax.name.text
    let args = parseTypeArguments(from: attribute)

    switch name {
    case "JSValueFieldCoding":
      if args.count >= 1 {
        decoder = args[0]
        encoder = args[0]
      }
      if args.count >= 2 {
        encoder = args[1]
      }
    case "JSValueFieldDecoding":
      if let first = args.first {
        decoder = first
      }
    case "JSValueFieldEncoding":
      if let first = args.first {
        encoder = first
      }
    default:
      continue
    }
  }

  return (decoder, encoder)
}

private func collectStoredProperties(from decl: StructDeclSyntax) -> [PropertyPlan] {
  var plans: [PropertyPlan] = []

  for member in decl.memberBlock.members {
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
          decoderOverride: overrides.decoder,
          encoderOverride: overrides.encoder
        ))
    }
  }

  return plans
}

public struct JSValueAutoConvertibleMacro: ExtensionMacro {
  public static func expansion(
    of node: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo _: [TypeSyntax],
    in _: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard let structDecl = declaration.as(StructDeclSyntax.self) else {
      throw MacroUsageError(description: "@JSValueAutoConvertible currently supports struct only")
    }

    let typeName = trimmed(type.description)
    let properties = collectStoredProperties(from: structDecl)
    let arguments = parseTypeArguments(from: node)

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
      throw MacroUsageError(description: "@JSValueAutoConvertible accepts 0, 1 or 2 type arguments")
    }

    let decodeBody: String
    let encodeBody: String

    if let decoder = sharedDecoder, let encoder = sharedEncoder {
      decodeBody = """
        return try \(decoder).tryDecode(value, in: context)
        """
      encodeBody = """
        return try \(encoder).tryEncode(self, in: context)
        """
    } else {
      var decodeLines: [String] = [
        "guard value.isObject else {",
        "  throw .typeMismatch(expected: \"object\", actual: value.type)",
        "}",
      ]

      var initArgs: [String] = []
      for property in properties {
        let keyName = "__key_\(property.name)"
        let localName = "__\(property.name)Value"
        decodeLines.append("let \(keyName) = JSStringManaged(\"\(property.name)\")")
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
        "let object = JSValue(objectIn: context)"
      ]
      for property in properties {
        let keyName = "__key_\(property.name)"
        let encodedName = "__encoded_\(property.name)"
        encodeLines.append("let \(keyName) = JSStringManaged(\"\(property.name)\")")
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
    }

    let extSource = """
      extension \(typeName): JSValueCodable {
        public init(value: borrowing JSValue, in context: isolated JSContext = #isolation) {
          do {
            self = try Self.tryDecode(value, in: context)
          } catch {
            fatalError("\(typeName).init(value:in:) failed: \\(error)")
          }
        }

        public static func tryDecode(
          _ value: borrowing JSValue,
          in context: isolated JSContext = #isolation
        ) throws(JSValueConversionError) -> Self {
          \(decodeBody)
        }

        public func toJSValue(in context: isolated JSContext = #isolation) -> JSValue {
          do {
            return try self.tryEncode(in: context)
          } catch {
            return JSValue(undefinedIn: context)
          }
        }

        public func tryEncode(
          in context: isolated JSContext = #isolation
        ) throws(JSValueConversionError) -> JSValue {
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
    JSValueAutoConvertibleMacro.self,
    JSValueFieldMarkerMacro.self,
  ]
}
