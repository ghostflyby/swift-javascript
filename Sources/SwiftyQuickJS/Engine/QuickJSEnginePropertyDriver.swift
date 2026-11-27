import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

extension QJSEngine {
  package static func makePropertyStringAtom(
    _ value: String,
    in context: OpaquePointer
  ) -> JSAtom? {
    let atom = value.withCString { pointer in
      JS_NewAtomLen(context, pointer, value.utf8.count)
    }
    return atom == 0 ? nil : atom
  }

  package static func makePropertyStringAtom(
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
  package static func makeStringValue(
    fromAtom atom: JSAtom,
    in context: OpaquePointer
  ) -> CQuickJSValue? {
    return JS_AtomToString(context, atom)
  }

  package static func propertyNames(
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
      atomString(propertyEnumPointer[index].atom, in: context)
    }
  }

  package static func getStaticStringProperty(
    _ key: StaticString,
    on object: CQuickJSValue,
    in context: OpaquePointer
  ) -> JSResult<CQuickJSValue>? {
    withPropertyStringAtom(key, in: context) { atom in
      quickJSResult(for: JS_GetProperty(context, object, atom), in: context)
    }
  }

  package static func getProperty(
    atom: JSAtom,
    on object: CQuickJSValue,
    in context: OpaquePointer
  ) -> JSResult<CQuickJSValue>? {
    return quickJSResult(for: JS_GetProperty(context, object, atom), in: context)
  }

  package static func setStaticStringProperty(
    _ key: StaticString,
    on object: CQuickJSValue,
    to value: CQuickJSValue,
    in context: OpaquePointer,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    withPropertyStringAtom(key, in: context) { atom in
      defineProperty(atom, on: object, to: value, in: context, attributes: attributes)
    } ?? false
  }

  package static func setProperty(
    atom: JSAtom,
    on object: CQuickJSValue,
    to value: CQuickJSValue,
    in context: OpaquePointer,
    attributes: JSHostMemberAttributes = .none
  ) -> Bool {
    defineProperty(atom, on: object, to: value, in: context, attributes: attributes)
  }

  package static func getValueProperty(
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

  package static func getIndexProperty(
    at index: UInt32,
    on object: CQuickJSValue,
    in context: OpaquePointer
  ) -> JSResult<CQuickJSValue>? {
    return quickJSResult(
      for: JS_GetPropertyUint32(context, object, index),
      in: context
    )
  }

  package static func setValueProperty(
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
    return defineProperty(atom, on: object, to: value, in: context, attributes: attributes)
  }

  package static func setIndexProperty(
    at index: UInt32,
    on object: CQuickJSValue,
    to value: CQuickJSValue,
    in context: OpaquePointer
  ) -> Bool {
    return JS_SetPropertyUint32(context, object, index, JS_DupValue(context, value))
      == 1
  }

  package static func hasProperty(
    atom: JSAtom,
    on object: CQuickJSValue,
    in context: OpaquePointer
  ) -> Bool? {
    let result = JS_HasProperty(context, object, atom)
    return result >= 0 ? result == 1 : nil
  }

  package static func hasStaticStringProperty(
    _ key: StaticString,
    on object: CQuickJSValue,
    in context: OpaquePointer
  ) -> Bool? {
    let result = withPropertyStringAtom(key, in: context) { atom in
      JS_HasProperty(context, object, atom)
    }
    guard let result, result >= 0 else { return nil }
    return result == 1
  }

  package static func hasValueProperty(
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

  package static func deleteProperty(
    atom: JSAtom,
    on object: CQuickJSValue,
    in context: OpaquePointer
  ) -> Bool {
    return JS_DeleteProperty(context, object, atom, Int32(JS_PROP_THROW)) == 1
  }

  package static func deleteStaticStringProperty(
    _ key: StaticString,
    on object: CQuickJSValue,
    in context: OpaquePointer
  ) -> Bool {
    withPropertyStringAtom(key, in: context) { atom in
      JS_DeleteProperty(context, object, atom, Int32(JS_PROP_THROW)) == 1
    } ?? false
  }

  package static func deleteValueProperty(
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
}

private func withPropertyStringAtom<R>(
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

private func withPropertyStringAtom<R>(
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

private func defineProperty(
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
    propertyFlags(for: attributes)
  ) == 1
}

private func atomString(_ atom: JSAtom, in contextRef: OpaquePointer) -> String? {
  var length = 0
  guard let cString = JS_AtomToCStringLen(contextRef, &length, atom) else {
    return nil
  }
  defer { JS_FreeCString(contextRef, cString) }
  let bytes = UnsafeRawPointer(cString).assumingMemoryBound(to: UInt8.self)
  return String(decoding: UnsafeBufferPointer(start: bytes, count: length), as: UTF8.self)
}

private func propertyFlags(for attributes: JSHostMemberAttributes) -> Int32 {
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
