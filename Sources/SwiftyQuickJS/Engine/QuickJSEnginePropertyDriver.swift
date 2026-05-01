import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

extension QuickJSEngine: JSEnginePropertyDriver {
  public static func makePropertyKeyHandle(
    _ value: String,
    in context: QuickJSContextHandle
  ) -> QuickJSPropertyKeyHandle? {
    let bytes = Array(value.utf8) + [0]
    let atom = bytes.withUnsafeBufferPointer { buffer in
      JS_NewAtomLen(
        context.ref,
        UnsafeRawPointer(buffer.baseAddress!).assumingMemoryBound(to: CChar.self),
        bytes.count - 1
      )
    }
    guard atom != 0 else {
      return nil
    }
    return QuickJSPropertyKeyHandle(atom: atom, contextRef: context.ref)
  }

  public static func isPropertyKeyHandleCompatibleWithContext(
    _ key: QuickJSPropertyKeyHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    key.contextRef == context.ref
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

  public static func getPropertyKeyHandle(
    _ key: QuickJSPropertyKeyHandle,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> JSResult<QuickJSValueHandle>? {
    let result = JS_GetProperty(context.ref, object.ref, key.atom)
    return quickJSResultHandle(for: result, in: context.ref)
  }

  public static func setPropertyKeyHandle(
    _ key: QuickJSPropertyKeyHandle,
    on object: QuickJSValueHandle,
    to value: QuickJSValueHandle,
    in context: QuickJSContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    if attributes.isEmpty {
      return JS_SetProperty(context.ref, object.ref, key.atom, JS_DupValue(context.ref, value.ref))
        == 1
    }
    return JS_DefinePropertyValue(
      context.ref,
      object.ref,
      key.atom,
      JS_DupValue(context.ref, value.ref),
      propertyFlags(for: attributes)
    ) == 1
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

  public static func hasPropertyKeyHandle(
    _ key: QuickJSPropertyKeyHandle,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool? {
    let result = JS_HasProperty(context.ref, object.ref, key.atom)
    return result >= 0 ? result == 1 : nil
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

  public static func deletePropertyKeyHandle(
    _ key: QuickJSPropertyKeyHandle,
    on object: QuickJSValueHandle,
    in context: QuickJSContextHandle
  ) -> Bool {
    return JS_DeleteProperty(context.ref, object.ref, key.atom, Int32(JS_PROP_THROW)) == 1
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
