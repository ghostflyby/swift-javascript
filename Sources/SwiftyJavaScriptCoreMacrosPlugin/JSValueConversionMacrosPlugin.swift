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
  let isMutable: Bool
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

private func inheritedClassName(from decl: ClassDeclSyntax) -> String? {
  guard let inheritanceClause = decl.inheritanceClause,
    let inheritedType = inheritanceClause.inheritedTypes.first
  else {
    return nil
  }

  return trimmed(inheritedType.type.description)
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
    let properties = collectStoredProperties(from: structDecl.memberBlock.members)
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
        public init(value: borrowing JSValue, in context: borrowing JSCallbackContext) {
          do {
            self = try Self.tryDecode(value, in: context)
          } catch {
            fatalError("\(typeName).init(value:in:) failed: \\(error)")
          }
        }

        public static func tryDecode(
          _ value: borrowing JSValue,
          in context: borrowing JSCallbackContext
        ) throws(JSValueConversionError) -> Self {
          \(decodeBody)
        }

        public func toJSValue(in context: borrowing JSCallbackContext) -> JSValue {
          do {
            return try self.tryEncode(in: context)
          } catch {
            return JSValue(undefinedIn: context)
          }
        }

        public func tryEncode(
          in context: borrowing JSCallbackContext
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
    let inheritedClass = inheritedClassName(from: classDecl)

    let declarationModifier = inheritedClass == nil ? "public class" : "public override class"

    let parentClassSetup: String
    let parentHasPropertyFallback: String
    let parentGetPropertyFallback: String
    let parentSetPropertyFallback: String

    if let inheritedClass {
      parentClassSetup = """
        definition.parentClass = \(inheritedClass).jsClass
        """
      parentHasPropertyFallback = """
              return \(inheritedClass).jsClassDefinition.hasProperty?(context, this, property) ?? false
        """
      parentGetPropertyFallback = """
              return \(inheritedClass).jsClassDefinition.getProperty?(context, this, property)
                ?? .value(JSValue(undefinedIn: context))
        """
      parentSetPropertyFallback = """
              return \(inheritedClass).jsClassDefinition.setProperty?(context, this, property, value)
        """
    } else {
      parentClassSetup = ""
      parentHasPropertyFallback = "              return false"
      parentGetPropertyFallback = "              return .value(JSValue(undefinedIn: context))"
      parentSetPropertyFallback = "              return nil"
    }

    let hasPropertyCases = properties.map { "case \"\($0.name)\": return true" }
      .joined(separator: "\n")

    let getPropertyCases = properties.map { property in
      let encodeLine: String
      if let encoder = property.encoderOverride {
        encodeLine =
          "return .value((try? \(encoder).tryEncode(instance.\(property.name), in: context)) ?? JSValue(undefinedIn: context))"
      } else {
        encodeLine =
          "return .value((try? instance.\(property.name).tryEncode(in: context)) ?? JSValue(undefinedIn: context))"
      }

      return """
            case \"\(property.name)\":
              \(encodeLine)
        """
    }.joined(separator: "\n")

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
              return JSValue(string: "\\(error)", in: context)
            }
        """
    }.joined(separator: "\n")

    let propertySource = """
      \(declarationModifier) var jsClassDefinition: JSClassDefinition {
        var definition = JSClassDefinition()
        definition.className = \"\(trimmed(classDecl.name.text))\"
        \(parentClassSetup)
        definition.hasProperty = { context, this, property in
          switch property {
          \(hasPropertyCases)
          default:
        \(parentHasPropertyFallback)
          }
        }
        definition.getProperty = { context, this, property in
          guard let instance = try? Self.tryDecode(this, in: context) else {
            return .value(JSValue(undefinedIn: context))
          }
          switch property {
          \(getPropertyCases)
          default:
        \(parentGetPropertyFallback)
          }
        }
        definition.setProperty = { context, this, property, value in
          guard let instance = try? Self.tryDecode(this, in: context) else {
            return JSValue(string: \"failed to decode \\(Self.self) backing instance\", in: context)
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
    JSValueAutoConvertibleMacro.self,
    JSClassAutoConvertibleMacro.self,
    JSValueFieldMarkerMacro.self,
  ]
}
