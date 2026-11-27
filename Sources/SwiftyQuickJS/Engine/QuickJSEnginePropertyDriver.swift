import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

package func quickJSMakePropertyStringAtom(
  _ value: String,
  in context: OpaquePointer
) -> JSAtom? {
  let atom = value.withCString { pointer in
    JS_NewAtomLen(context, pointer, value.utf8.count)
  }
  return atom == 0 ? nil : atom
}

package func quickJSMakePropertyStringAtom(
  _ value: StaticString,
  in context: OpaquePointer
) -> JSAtom? {
  let atom = value.withUTF8Buffer { buffer in
    let pointer = buffer.baseAddress.map {
      UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)
    }
    return JS_NewAtomLen(context, pointer, buffer.count)
  }
  return atom == 0 ? nil : atom
}

/// A new owning value reference for the key's atom.
package func quickJSMakeStringValue(
  fromAtom atom: JSAtom,
  in context: OpaquePointer
) -> CQuickJSValue? {
  return JS_AtomToString(context, atom)
}

package func quickJSPropertyNames(
  on object: CQuickJSValue,
  in context: OpaquePointer
) -> [String]? {
  var propertyEnumPointer: UnsafeMutablePointer<JSPropertyEnum>?
  var propertyCount: UInt32 = 0
  let flags = Int32(JS_GPN_STRING_MASK | JS_GPN_ENUM_ONLY)
  guard
    JS_GetOwnPropertyNames(
      context,
      &propertyEnumPointer,
      &propertyCount,
      object,
      flags
    ) == 0
  else {
    return nil
  }
  guard let propertyEnumPointer else {
    return []
  }
  defer {
    JS_FreePropertyEnum(context, propertyEnumPointer, propertyCount)
  }
  return (0..<Int(propertyCount)).compactMap { index in
    quickJSAtomString(propertyEnumPointer[index].atom, in: context)
  }
}

package func quickJSGetStaticStringProperty(
  _ key: StaticString,
  on object: CQuickJSValue,
  in context: OpaquePointer
) -> JSResult<CQuickJSValue>? {
  quickJSWithPropertyStringAtom(key, in: context) { atom in
    quickJSResult(for: JS_GetProperty(context, object, atom), in: context)
  }
}

package func quickJSGetProperty(
  atom: JSAtom,
  on object: CQuickJSValue,
  in context: OpaquePointer
) -> JSResult<CQuickJSValue>? {
  return quickJSResult(for: JS_GetProperty(context, object, atom), in: context)
}

package func quickJSSetStaticStringProperty(
  _ key: StaticString,
  on object: CQuickJSValue,
  to value: CQuickJSValue,
  in context: OpaquePointer,
  attributes: JSHostMemberAttributes = .none
) -> Bool {
  quickJSWithPropertyStringAtom(key, in: context) { atom in
    quickJSDefineProperty(atom, on: object, to: value, in: context, attributes: attributes)
  } ?? false
}

package func quickJSSetProperty(
  atom: JSAtom,
  on object: CQuickJSValue,
  to value: CQuickJSValue,
  in context: OpaquePointer,
  attributes: JSHostMemberAttributes = .none
) -> Bool {
  quickJSDefineProperty(atom, on: object, to: value, in: context, attributes: attributes)
}

package func quickJSGetValueProperty(
  _ key: CQuickJSValue,
  on object: CQuickJSValue,
  in context: OpaquePointer
) -> JSResult<CQuickJSValue>? {
  let atom = JS_ValueToAtom(context, key)
  guard atom != 0 else {
    return nil
  }
  defer { JS_FreeAtom(context, atom) }
  return quickJSResult(for: JS_GetProperty(context, object, atom), in: context)
}

package func quickJSGetIndexProperty(
  at index: UInt32,
  on object: CQuickJSValue,
  in context: OpaquePointer
) -> JSResult<CQuickJSValue>? {
  return quickJSResult(
    for: JS_GetPropertyUint32(context, object, index),
    in: context
  )
}

package func quickJSSetValueProperty(
  _ key: CQuickJSValue,
  on object: CQuickJSValue,
  to value: CQuickJSValue,
  in context: OpaquePointer,
  attributes: JSHostMemberAttributes = .none
) -> Bool {
  let atom = JS_ValueToAtom(context, key)
  guard atom != 0 else {
    return false
  }
  defer { JS_FreeAtom(context, atom) }
  return quickJSDefineProperty(atom, on: object, to: value, in: context, attributes: attributes)
}

package func quickJSSetIndexProperty(
  at index: UInt32,
  on object: CQuickJSValue,
  to value: CQuickJSValue,
  in context: OpaquePointer
) -> Bool {
  return JS_SetPropertyUint32(context, object, index, JS_DupValue(context, value))
    == 1
}

package func quickJSHasProperty(
  atom: JSAtom,
  on object: CQuickJSValue,
  in context: OpaquePointer
) -> Bool? {
  let result = JS_HasProperty(context, object, atom)
  return result >= 0 ? result == 1 : nil
}

package func quickJSHasStaticStringProperty(
  _ key: StaticString,
  on object: CQuickJSValue,
  in context: OpaquePointer
) -> Bool? {
  let result = quickJSWithPropertyStringAtom(key, in: context) { atom in
    JS_HasProperty(context, object, atom)
  }
  guard let result, result >= 0 else { return nil }
  return result == 1
}

package func quickJSHasValueProperty(
  _ key: CQuickJSValue,
  on object: CQuickJSValue,
  in context: OpaquePointer
) -> Bool? {
  let atom = JS_ValueToAtom(context, key)
  guard atom != 0 else {
    return nil
  }
  defer { JS_FreeAtom(context, atom) }
  let result = JS_HasProperty(context, object, atom)
  return result >= 0 ? result == 1 : nil
}

package func quickJSDeleteProperty(
  atom: JSAtom,
  on object: CQuickJSValue,
  in context: OpaquePointer
) -> Bool {
  return JS_DeleteProperty(context, object, atom, Int32(JS_PROP_THROW)) == 1
}

package func quickJSDeleteStaticStringProperty(
  _ key: StaticString,
  on object: CQuickJSValue,
  in context: OpaquePointer
) -> Bool {
  quickJSWithPropertyStringAtom(key, in: context) { atom in
    JS_DeleteProperty(context, object, atom, Int32(JS_PROP_THROW)) == 1
  } ?? false
}

package func quickJSDeleteValueProperty(
  _ key: CQuickJSValue,
  on object: CQuickJSValue,
  in context: OpaquePointer
) -> Bool {
  let atom = JS_ValueToAtom(context, key)
  guard atom != 0 else {
    return false
  }
  defer { JS_FreeAtom(context, atom) }
  return JS_DeleteProperty(context, object, atom, Int32(JS_PROP_THROW)) == 1
}

private func quickJSWithPropertyStringAtom<R>(
  _ value: String,
  in context: OpaquePointer,
  _ body: (JSAtom) -> R
) -> R? {
  let atom = value.withCString { pointer in
    JS_NewAtomLen(context, pointer, value.utf8.count)
  }
  guard atom != 0 else {
    return nil
  }
  defer { JS_FreeAtom(context, atom) }
  return body(atom)
}

private func quickJSWithPropertyStringAtom<R>(
  _ value: StaticString,
  in context: OpaquePointer,
  _ body: (JSAtom) -> R
) -> R? {
  let atom = value.withUTF8Buffer { buffer in
    let pointer = buffer.baseAddress.map {
      UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)
    }
    return JS_NewAtomLen(context, pointer, buffer.count)
  }
  guard atom != 0 else {
    return nil
  }
  defer { JS_FreeAtom(context, atom) }
  return body(atom)
}

private func quickJSDefineProperty(
  _ atom: JSAtom,
  on object: CQuickJSValue,
  to value: CQuickJSValue,
  in context: OpaquePointer,
  attributes: JSHostMemberAttributes
) -> Bool {
  if attributes.isEmpty {
    return JS_SetProperty(context, object, atom, JS_DupValue(context, value)) == 1
  }
  return JS_DefinePropertyValue(
    context,
    object,
    atom,
    JS_DupValue(context, value),
    quickJSPropertyFlags(for: attributes)
  ) == 1
}

private func quickJSAtomString(_ atom: JSAtom, in contextRef: OpaquePointer) -> String? {
  var length = 0
  guard let cString = JS_AtomToCStringLen(contextRef, &length, atom) else {
    return nil
  }
  defer { JS_FreeCString(contextRef, cString) }
  let bytes = UnsafeRawPointer(cString).assumingMemoryBound(to: UInt8.self)
  return String(decoding: UnsafeBufferPointer(start: bytes, count: length), as: UTF8.self)
}

private func quickJSPropertyFlags(for attributes: JSHostMemberAttributes) -> Int32 {
  var flags = Int32(
    JS_PROP_HAS_VALUE | JS_PROP_HAS_CONFIGURABLE | JS_PROP_HAS_WRITABLE
      | JS_PROP_HAS_ENUMERABLE | JS_PROP_THROW)
  if !attributes.contains(.dontDelete) {
    flags |= Int32(JS_PROP_CONFIGURABLE)
  }
  if !attributes.contains(.readOnly) {
    flags |= Int32(JS_PROP_WRITABLE)
  }
  if !attributes.contains(.dontEnum) {
    flags |= Int32(JS_PROP_ENUMERABLE)
  }
  return flags
}
