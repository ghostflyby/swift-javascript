import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

extension QuickJSEngine: JSEnginePropertyDriver {
  public static func makePropertyStringKeyHandle(
    _ value: String,
    in context: QuickJSContextHandle
  ) -> QuickJSPropertyStringKeyHandle? {
    let atom = makePropertyStringAtom(value, in: context)
    guard atom != 0 else {
      return nil
    }
    return QuickJSPropertyStringKeyHandle(atom: atom, contextRef: context.ref)
  }

  public static func makePropertyStringKeyHandle(
    _ value: StaticString,
    in context: QuickJSContextHandle
  ) -> QuickJSPropertyStringKeyHandle? {
    let atom = makePropertyStringAtom(value, in: context)
    guard atom != 0 else {
      return nil
    }
    return QuickJSPropertyStringKeyHandle(atom: atom, contextRef: context.ref)
  }

  public static func isPropertyStringKeyHandleCompatibleWithContext(
    _ key: QuickJSPropertyStringKeyHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    key.contextRef == context.ref
  }

  public static func makeStringValueHandle(
    fromPropertyStringKey key: QuickJSPropertyStringKeyHandle,
    in context: QuickJSContextHandle
  ) -> QuickJSOwnedValueHandle? {
    let value = JS_AtomToString(context.ref, key.atom)
    return QuickJSOwnedValueHandle(ref: value)
  }

  public static func propertyNamesForHandle(
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> [String]? {
    var propertyEnumPointer: UnsafeMutablePointer<JSPropertyEnum>?
    var propertyCount: UInt32 = 0
    let flags = Int32(JS_GPN_STRING_MASK | JS_GPN_ENUM_ONLY)
    guard
      JS_GetOwnPropertyNames(
        context.ref,
        &propertyEnumPointer,
        &propertyCount,
        object.ref,
        flags
      ) == 0
    else {
      return nil
    }
    guard let propertyEnumPointer else {
      return []
    }
    defer {
      JS_FreePropertyEnum(context.ref, propertyEnumPointer, propertyCount)
    }
    return (0..<Int(propertyCount)).compactMap { index in
      atomString(propertyEnumPointer[index].atom, in: context.ref)
    }
  }

  public static func getStaticStringPropertyHandle(
    _ key: StaticString,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    withPropertyStringAtom(key, in: context) { atom in
      quickJSResultHandle(for: JS_GetProperty(context.ref, object.ref, atom), in: context.ref)
    }
  }

  public static func getPropertyStringKeyHandle(
    _ key: QuickJSPropertyStringKeyHandle,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    let result = JS_GetProperty(context.ref, object.ref, key.atom)
    return quickJSResultHandle(for: result, in: context.ref)
  }

  public static func setStaticStringPropertyHandle(
    _ key: StaticString,
    on object: QuickJSValueHandle,
    to value: QuickJSValueHandle,
    in context: QuickJSContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    withPropertyStringAtom(key, in: context) { atom in
      setProperty(atom, on: object, to: value, in: context, attributes: attributes)
    } ?? false
  }

  public static func setPropertyStringKeyHandle(
    _ key: QuickJSPropertyStringKeyHandle,
    on object: QuickJSValueHandle,
    to value: QuickJSValueHandle,
    in context: QuickJSContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    setProperty(key.atom, on: object, to: value, in: context, attributes: attributes)
  }

  public static func getValuePropertyHandle(
    _ key: QuickJSValueHandle,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    let atom = JS_ValueToAtom(context.ref, key.ref)
    guard atom != 0 else {
      return nil
    }
    defer { JS_FreeAtom(context.ref, atom) }
    return quickJSResultHandle(for: JS_GetProperty(context.ref, object.ref, atom), in: context.ref)
  }

  public static func getIndexPropertyHandle(
    at index: UInt32,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    quickJSResultHandle(
      for: JS_GetPropertyUint32(context.ref, object.ref, index),
      in: context.ref
    )
  }

  public static func setValuePropertyHandle(
    _ key: QuickJSValueHandle,
    on object: QuickJSValueHandle,
    to value: QuickJSValueHandle,
    in context: QuickJSContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    let atom = JS_ValueToAtom(context.ref, key.ref)
    guard atom != 0 else {
      return false
    }
    defer { JS_FreeAtom(context.ref, atom) }
    if attributes.isEmpty {
      return JS_SetProperty(context.ref, object.ref, atom, JS_DupValue(context.ref, value.ref))
        == 1
    }
    return JS_DefinePropertyValue(
      context.ref,
      object.ref,
      atom,
      JS_DupValue(context.ref, value.ref),
      propertyFlags(for: attributes)
    ) == 1
  }

  public static func setIndexPropertyHandle(
    at index: UInt32,
    on object: QuickJSValueHandle,
    to value: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    return JS_SetPropertyUint32(context.ref, object.ref, index, JS_DupValue(context.ref, value.ref))
      == 1
  }

  public static func hasPropertyStringKeyHandle(
    _ key: QuickJSPropertyStringKeyHandle,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    let result = JS_HasProperty(context.ref, object.ref, key.atom)
    return result >= 0 ? result == 1 : nil
  }

  public static func hasStaticStringPropertyHandle(
    _ key: StaticString,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    guard
      let result = withPropertyStringAtom(
        key, in: context,
        { atom in
          let result = JS_HasProperty(context.ref, object.ref, atom)
          return result >= 0 ? result == 1 : nil
        })
    else {
      return nil
    }
    return result
  }

  public static func hasValuePropertyHandle(
    _ key: QuickJSValueHandle,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    let atom = JS_ValueToAtom(context.ref, key.ref)
    guard atom != 0 else {
      return nil
    }
    defer { JS_FreeAtom(context.ref, atom) }
    let result = JS_HasProperty(context.ref, object.ref, atom)
    return result >= 0 ? result == 1 : nil
  }

  public static func deletePropertyStringKeyHandle(
    _ key: QuickJSPropertyStringKeyHandle,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    return JS_DeleteProperty(context.ref, object.ref, key.atom, Int32(JS_PROP_THROW)) == 1
  }

  public static func deleteStaticStringPropertyHandle(
    _ key: StaticString,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    withPropertyStringAtom(key, in: context) { atom in
      JS_DeleteProperty(context.ref, object.ref, atom, Int32(JS_PROP_THROW)) == 1
    } ?? false
  }

  public static func deleteValuePropertyHandle(
    _ key: QuickJSValueHandle,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    let atom = JS_ValueToAtom(context.ref, key.ref)
    guard atom != 0 else {
      return false
    }
    defer { JS_FreeAtom(context.ref, atom) }
    return JS_DeleteProperty(context.ref, object.ref, atom, Int32(JS_PROP_THROW)) == 1
  }
}

private func makePropertyStringAtom(_ value: String, in context: QuickJSContextHandle) -> JSAtom {
  value.withCString { pointer in
    JS_NewAtomLen(
      context.ref,
      pointer,
      value.utf8.count
    )
  }
}

private func makePropertyStringAtom(
  _ value: StaticString,
  in context: QuickJSContextHandle
) -> JSAtom {
  value.withUTF8Buffer { buffer in
    let pointer = buffer.baseAddress.map {
      UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)
    }
    return JS_NewAtomLen(context.ref, pointer, buffer.count)
  }
}

private func withPropertyStringAtom<R>(
  _ value: String,
  in context: QuickJSContextHandle,
  _ body: (JSAtom) -> R
) -> R? {
  let atom = makePropertyStringAtom(value, in: context)
  guard atom != 0 else {
    return nil
  }
  defer { JS_FreeAtom(context.ref, atom) }
  return body(atom)
}

private func withPropertyStringAtom<R>(
  _ value: StaticString,
  in context: QuickJSContextHandle,
  _ body: (JSAtom) -> R
) -> R? {
  let atom = makePropertyStringAtom(value, in: context)
  guard atom != 0 else {
    return nil
  }
  defer { JS_FreeAtom(context.ref, atom) }
  return body(atom)
}

private func setProperty(
  _ atom: JSAtom,
  on object: QuickJSValueHandle,
  to value: QuickJSValueHandle,
  in context: QuickJSContextHandle,
  attributes: JSHostMemberAttributes
) -> Bool {
  if attributes.isEmpty {
    return JS_SetProperty(context.ref, object.ref, atom, JS_DupValue(context.ref, value.ref)) == 1
  }
  return JS_DefinePropertyValue(
    context.ref,
    object.ref,
    atom,
    JS_DupValue(context.ref, value.ref),
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
