@attached(
  extension,
  conformances: JSValueCodable,
  names: named(init(value:in:)),
  named(tryDecode(_:in:)),
  named(toJSValue(in:)),
  named(tryEncode(in:))
)
public macro JSValueAutoConvertible() =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueAutoConvertibleMacro"
  )

@attached(
  extension,
  conformances: JSValueCodable,
  names: named(init(value:in:)),
  named(tryDecode(_:in:)),
  named(toJSValue(in:)),
  named(tryEncode(in:))
)
public macro JSValueAutoConvertible(
  _ converter: any JSValueConverter.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueAutoConvertibleMacro"
  )

@attached(
  extension,
  conformances: JSValueCodable,
  names: named(init(value:in:)),
  named(tryDecode(_:in:)),
  named(toJSValue(in:)),
  named(tryEncode(in:))
)
public macro JSValueAutoConvertible(
  _ decoder: any JSValueDecoder.Type,
  _ encoder: any JSValueEncoder.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueAutoConvertibleMacro"
  )

@attached(peer, names: overloaded)
public macro JSValueFieldCoding(_ converter: any JSValueConverter.Type) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

@attached(peer, names: overloaded)
public macro JSValueFieldCoding(
  _ field: StaticString,
  _ converter: any JSValueConverter.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

@attached(peer, names: overloaded)
public macro JSValueFieldCoding(
  _ decoder: any JSValueDecoder.Type,
  _ encoder: any JSValueEncoder.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

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

@attached(peer, names: overloaded)
public macro JSValueFieldDecoding(_ decoder: any JSValueDecoder.Type) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

@attached(peer, names: overloaded)
public macro JSValueFieldDecoding(
  _ field: StaticString,
  _ decoder: any JSValueDecoder.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

@attached(peer, names: overloaded)
public macro JSValueFieldEncoding(_ encoder: any JSValueEncoder.Type) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

@attached(peer, names: overloaded)
public macro JSValueFieldEncoding(
  _ field: StaticString,
  _ encoder: any JSValueEncoder.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

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
