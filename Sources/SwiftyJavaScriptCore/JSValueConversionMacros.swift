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
  _ converter: Any.Type
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
  _ decoder: Any.Type,
  _ encoder: Any.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueAutoConvertibleMacro"
  )

@attached(peer, names: arbitrary)
public macro JSValueFieldCoding(_ converter: any JSValueConverter.Type) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

@attached(peer, names: arbitrary)
public macro JSValueFieldCoding(
  _ decoder: any JSValueDecoder.Type,
  _ encoder: any JSValueEncoder.Type
) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

@attached(peer, names: arbitrary)
public macro JSValueFieldDecoding(_ decoder: any JSValueDecoder.Type) =
  #externalMacro(
    module: "SwiftyJavaScriptCoreMacrosPlugin",
    type: "JSValueFieldMarkerMacro"
  )

@attached(peer, names: arbitrary)
public macro JSValueFieldEncoding(_ encoder: any JSValueEncoder.Type) =
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
