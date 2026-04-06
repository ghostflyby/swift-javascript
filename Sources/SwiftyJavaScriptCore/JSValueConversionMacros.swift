/// Generates default JS value serialization for a struct, enum, or final class.
///
/// The generated conformance uses value semantics. When applied to a final class,
/// decoding creates a new Swift instance and does not preserve object identity.
/// Use `JSClassAutoConvertible` instead when reference semantics or a JSClass-backed
/// prototype chain must be preserved.
///
/// For enums without associated values, the macro uses case names by default. Enums declared
/// with built-in raw-value syntax such as `enum Kind: String` or `enum Code: Int` are encoded
/// and decoded using `rawValue` instead. Only this built-in declaration form is recognized
/// automatically; a manual `RawRepresentable` conformance added later is not detected.
@attached(
  extension,
  conformances: JSValueCodable,
  names: named(init(value:in:)),
  named(tryDecode(_:in:)),
  named(toJSValue(in:)),
  named(tryEncode(in:))
)
public macro JSValueAutoSerialization() =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueAutoSerializationMacro"
  )

/// Generates default JS value serialization using custom tag and payload keys for
/// associated-value enums.
///
/// For enums without associated values, built-in raw-value declarations such as
/// `enum Kind: String` still use `rawValue` by default. Manual `RawRepresentable`
/// conformances are not detected automatically.
///
/// - Parameters:
///   - tagKey: The key used to store the case discriminator. The default shape uses `kind`.
///   - payloadKey: The key used to store the associated payload when the enum cannot be
///     flattened into top-level fields.
@attached(
  extension,
  conformances: JSValueCodable,
  names: named(init(value:in:)),
  named(tryDecode(_:in:)),
  named(toJSValue(in:)),
  named(tryEncode(in:))
)
public macro JSValueAutoSerialization(
  tagKey: StaticString,
  payloadKey: StaticString = "payload"
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueAutoSerializationMacro"
  )

/// Delegates serialization and deserialization to a single custom converter type.
///
/// - Parameter converter: A `JSValueConverter` that fully controls encoding and decoding.
@attached(
  extension,
  conformances: JSValueCodable,
  names: named(init(value:in:)),
  named(tryDecode(_:in:)),
  named(toJSValue(in:)),
  named(tryEncode(in:))
)
public macro JSValueAutoSerialization(
  _ converter: any JSValueConverter.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueAutoSerializationMacro"
  )

/// Delegates serialization and deserialization to a single custom converter type and
/// also configures associated-enum tag and payload keys.
///
/// - Parameters:
///   - converter: A `JSValueConverter` that fully controls encoding and decoding.
///   - tagKey: The key used to store the case discriminator.
///   - payloadKey: The key used to store the associated payload when the enum cannot be
///     flattened into top-level fields.
@attached(
  extension,
  conformances: JSValueCodable,
  names: named(init(value:in:)),
  named(tryDecode(_:in:)),
  named(toJSValue(in:)),
  named(tryEncode(in:))
)
public macro JSValueAutoSerialization(
  _ converter: any JSValueConverter.Type,
  tagKey: StaticString,
  payloadKey: StaticString = "payload"
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueAutoSerializationMacro"
  )

/// Delegates deserialization and serialization to separate custom types.
///
/// - Parameters:
///   - decoder: A `JSValueDecoder` used for decoding from JavaScript values.
///   - encoder: A `JSValueEncoder` used for encoding into JavaScript values.
@attached(
  extension,
  conformances: JSValueCodable,
  names: named(init(value:in:)),
  named(tryDecode(_:in:)),
  named(toJSValue(in:)),
  named(tryEncode(in:))
)
public macro JSValueAutoSerialization(
  _ decoder: any JSValueDecoder.Type,
  _ encoder: any JSValueEncoder.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueAutoSerializationMacro"
  )

/// Delegates deserialization and serialization to separate custom types and also
/// configures associated-enum tag and payload keys.
///
/// - Parameters:
///   - decoder: A `JSValueDecoder` used for decoding from JavaScript values.
///   - encoder: A `JSValueEncoder` used for encoding into JavaScript values.
///   - tagKey: The key used to store the case discriminator.
///   - payloadKey: The key used to store the associated payload when the enum cannot be
///     flattened into top-level fields.
@attached(
  extension,
  conformances: JSValueCodable,
  names: named(init(value:in:)),
  named(tryDecode(_:in:)),
  named(toJSValue(in:)),
  named(tryEncode(in:))
)
public macro JSValueAutoSerialization(
  _ decoder: any JSValueDecoder.Type,
  _ encoder: any JSValueEncoder.Type,
  tagKey: StaticString,
  payloadKey: StaticString = "payload"
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueAutoSerializationMacro"
  )

/// Overrides both decoding and encoding for the attached stored property using a
/// single converter type.
///
/// For associated-value enums, attach this to the enum declaration and pass a selector
/// like `caseName`, `caseName.0`, or `caseName.label`.
///
/// - Parameter converter: The converter used for both decoding and encoding.
@attached(peer, names: overloaded)
public macro JSValueFieldCoding(_ converter: any JSValueConverter.Type) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Overrides both decoding and encoding for a selected associated value using a
/// single converter type.
///
/// - Parameters:
///   - field: The associated-value selector, such as `caseName`, `caseName.0`, or
///     `caseName.label`.
///   - converter: The converter used for both decoding and encoding.
@attached(peer, names: overloaded)
public macro JSValueFieldCoding(
  _ field: StaticString,
  _ converter: any JSValueConverter.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Overrides decoding and encoding for the attached stored property using separate
/// custom types.
///
/// - Parameters:
///   - decoder: The decoder used when reading from a JavaScript value.
///   - encoder: The encoder used when writing to a JavaScript value.
@attached(peer, names: overloaded)
public macro JSValueFieldCoding(
  _ decoder: any JSValueDecoder.Type,
  _ encoder: any JSValueEncoder.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Overrides decoding and encoding for a selected associated value using separate
/// custom types.
///
/// - Parameters:
///   - field: The associated-value selector, such as `caseName`, `caseName.0`, or
///     `caseName.label`.
///   - decoder: The decoder used when reading from a JavaScript value.
///   - encoder: The encoder used when writing to a JavaScript value.
@attached(peer, names: overloaded)
public macro JSValueFieldCoding(
  _ field: StaticString,
  _ decoder: any JSValueDecoder.Type,
  _ encoder: any JSValueEncoder.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Overrides decoding for the attached stored property.
///
/// For associated-value enums, attach this to the enum declaration and pass a selector
/// like `caseName`, `caseName.0`, or `caseName.label`.
///
/// - Parameter decoder: The decoder used when reading from a JavaScript value.
@attached(peer, names: overloaded)
public macro JSValueFieldDecoding(_ decoder: any JSValueDecoder.Type) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Overrides decoding for a selected associated value.
///
/// - Parameters:
///   - field: The associated-value selector, such as `caseName`, `caseName.0`, or
///     `caseName.label`.
///   - decoder: The decoder used when reading from a JavaScript value.
@attached(peer, names: overloaded)
public macro JSValueFieldDecoding(
  _ field: StaticString,
  _ decoder: any JSValueDecoder.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Overrides encoding for the attached stored property.
///
/// For associated-value enums, attach this to the enum declaration and pass a selector
/// like `caseName`, `caseName.0`, or `caseName.label`.
///
/// - Parameter encoder: The encoder used when writing to a JavaScript value.
@attached(peer, names: overloaded)
public macro JSValueFieldEncoding(_ encoder: any JSValueEncoder.Type) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Overrides encoding for a selected associated value.
///
/// - Parameters:
///   - field: The associated-value selector, such as `caseName`, `caseName.0`, or
///     `caseName.label`.
///   - encoder: The encoder used when writing to a JavaScript value.
@attached(peer, names: overloaded)
public macro JSValueFieldEncoding(
  _ field: StaticString,
  _ encoder: any JSValueEncoder.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Marks an instance method for export as a JavaScript function on a `JSClass`.
///
/// The generated function is added to `staticFunctions` in the synthesized
/// `jsClassDefinition` and is invoked with `this` bound to the exported Swift instance.
/// Parameters are decoded from JavaScript arguments and the return value is encoded
/// back into JavaScript using the method signature by default.
@attached(peer, names: overloaded)
public macro JSClassFunction() =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Marks an instance method for export as a JavaScript function using a custom JS name.
///
/// - Parameter name: The JavaScript-visible function name.
@attached(peer, names: overloaded)
public macro JSClassFunction(_ name: StaticString) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Overrides argument decoders for an exported `JSClass` method.
///
/// The number of decoders must match the number of method parameters.
@attached(peer, names: overloaded)
public macro JSClassFunctionArguments(_ decoders: any JSValueDecoder.Type...) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Overrides the return-value encoder for an exported `JSClass` method.
@attached(peer, names: overloaded)
public macro JSClassFunctionReturn(_ encoder: any JSValueEncoder.Type) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Overrides the thrown-error encoder for an exported `JSClass` method.
///
/// This only applies to throwing methods.
@attached(peer, names: overloaded)
public macro JSClassFunctionError(_ encoder: any JSValueEncoder.Type) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

/// Generates a `SwiftJavaScript.JSClassDefinition<JavaScriptCoreEngine, JSClass, JSPropertyNameAccumulatorRef>` and `JSClassValueConvertible` conformance for a
/// Swift class.
///
/// Unlike `JSValueAutoSerialization`, this macro preserves reference semantics by
/// exporting the Swift instance as a JSClass-backed object whose identity, prototype
/// chain, and inheritance chain remain visible to JavaScript.
/// Stored properties are exported automatically. Methods are exported only when they are
/// marked with `JSClassFunction`, optionally combined with `JSClassFunctionArguments`,
/// `JSClassFunctionReturn`, and `JSClassFunctionError`.
@attached(member, names: named(jsClassDefinition))
@attached(
  extension,
  conformances: JSClassValueConvertible
)
public macro JSClassAutoConvertible() =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSClassAutoConvertibleMacro"
  )
