import SwiftJavaScript

#if canImport(CQuickJSStatic)
  import CQuickJSStatic
#elseif canImport(CQuickJSDynamic)
  import CQuickJSDynamic
#elseif canImport(CQuickJSSystem)
  import CQuickJSSystem
#endif

extension QJSEngine: JSEnginePropertyDriver {
  package static func makePropertyStringKeyHandle(
    _ value: String,
    in context: QJSContextHandle
  ) -> QJSPropertyStringKeyHandle? {
    let atom = makePropertyStringAtom(value, in: context)
    guard atom != 0 else {
      return nil
    }
    return QJSPropertyStringKeyHandle(atom: atom, contextRef: context.ref)
  }

  package static func makePropertyStringKeyHandle(
    _ value: StaticString,
    in context: QJSContextHandle
  ) -> QJSPropertyStringKeyHandle? {
    let atom = makePropertyStringAtom(value, in: context)
    guard atom != 0 else {
      return nil
    }
    return QJSPropertyStringKeyHandle(atom: atom, contextRef: context.ref)
  }

  package static func isPropertyStringKeyHandleCompatibleWithContext(
    _ key: QJSPropertyStringKeyHandle,
    in context: QJSContextHandle
  ) -> Bool {
    key.contextRef == context.ref
  }

  package static func makeStringValueHandle(
    fromPropertyStringKey key: QJSPropertyStringKeyHandle,
    in context: QJSContextHandle
  ) -> QJSOwnedValueHandle? {
    let value = JS_AtomToString(context.ref, key.atom)
    return QJSOwnedValueHandle(ref: value)
  }

  package static func propertyNamesForHandle(
    on object: QJSValueHandle,
    in context: QJSContextHandle
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

  package static func getStaticStringPropertyHandle(
    _ key: StaticString,
    on object: QJSValueHandle,
    in context: QJSContextHandle
  ) -> JSResult<QJSValueHandle>? {
    withPropertyStringAtom(key, in: context) { atom in
      quickJSResultHandle(for: JS_GetProperty(context.ref, object.ref, atom), in: context.ref)
    }
  }

  package static func getPropertyStringKeyHandle(
    _ key: QJSPropertyStringKeyHandle,
    on object: QJSValueHandle,
    in context: QJSContextHandle
  ) -> JSResult<QJSValueHandle>? {
    let result = JS_GetProperty(context.ref, object.ref, key.atom)
    return quickJSResultHandle(for: result, in: context.ref)
  }

  package static func setStaticStringPropertyHandle(
    _ key: StaticString,
    on object: QJSValueHandle,
    to value: QJSValueHandle,
    in context: QJSContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    withPropertyStringAtom(key, in: context) { atom in
      setProperty(atom, on: object, to: value, in: context, attributes: attributes)
    } ?? false
  }

  package static func setPropertyStringKeyHandle(
    _ key: QJSPropertyStringKeyHandle,
    on object: QJSValueHandle,
    to value: QJSValueHandle,
    in context: QJSContextHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    setProperty(key.atom, on: object, to: value, in: context, attributes: attributes)
  }

  package static func getValuePropertyHandle(
    _ key: QJSValueHandle,
    on object: QJSValueHandle,
    in context: QJSContextHandle
  ) -> JSResult<QJSValueHandle>? {
    let atom = JS_ValueToAtom(context.ref, key.ref)
    guard atom != 0 else {
      return nil
    }
    defer { JS_FreeAtom(context.ref, atom) }
    return quickJSResultHandle(for: JS_GetProperty(context.ref, object.ref, atom), in: context.ref)
  }

  package static func getIndexPropertyHandle(
    at index: UInt32,
    on object: QJSValueHandle,
    in context: QJSContextHandle
  ) -> JSResult<QJSValueHandle>? {
    quickJSResultHandle(
      for: JS_GetPropertyUint32(context.ref, object.ref, index),
      in: context.ref
    )
  }

  package static func setValuePropertyHandle(
    _ key: QJSValueHandle,
    on object: QJSValueHandle,
    to value: QJSValueHandle,
    in context: QJSContextHandle,
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

  package static func setIndexPropertyHandle(
    at index: UInt32,
    on object: QJSValueHandle,
    to value: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool {
    return JS_SetPropertyUint32(context.ref, object.ref, index, JS_DupValue(context.ref, value.ref))
      == 1
  }

  package static func hasPropertyStringKeyHandle(
    _ key: QJSPropertyStringKeyHandle,
    on object: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool? {
    let result = JS_HasProperty(context.ref, object.ref, key.atom)
    return result >= 0 ? result == 1 : nil
  }

  package static func hasStaticStringPropertyHandle(
    _ key: StaticString,
    on object: QJSValueHandle,
    in context: QJSContextHandle
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

  package static func hasValuePropertyHandle(
    _ key: QJSValueHandle,
    on object: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool? {
    let atom = JS_ValueToAtom(context.ref, key.ref)
    guard atom != 0 else {
      return nil
    }
    defer { JS_FreeAtom(context.ref, atom) }
    let result = JS_HasProperty(context.ref, object.ref, atom)
    return result >= 0 ? result == 1 : nil
  }

  package static func deletePropertyStringKeyHandle(
    _ key: QJSPropertyStringKeyHandle,
    on object: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool {
    return JS_DeleteProperty(context.ref, object.ref, key.atom, Int32(JS_PROP_THROW)) == 1
  }

  package static func deleteStaticStringPropertyHandle(
    _ key: StaticString,
    on object: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool {
    withPropertyStringAtom(key, in: context) { atom in
      JS_DeleteProperty(context.ref, object.ref, atom, Int32(JS_PROP_THROW)) == 1
    } ?? false
  }

  package static func deleteValuePropertyHandle(
    _ key: QJSValueHandle,
    on object: QJSValueHandle,
    in context: QJSContextHandle
  ) -> Bool {
    let atom = JS_ValueToAtom(context.ref, key.ref)
    guard atom != 0 else {
      return false
    }
    defer { JS_FreeAtom(context.ref, atom) }
    return JS_DeleteProperty(context.ref, object.ref, atom, Int32(JS_PROP_THROW)) == 1
  }
}

private func makePropertyStringAtom(_ value: String, in context: QJSContextHandle) -> JSAtom {
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
  in context: QJSContextHandle
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
  in context: QJSContextHandle,
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
  in context: QJSContextHandle,
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
  on object: QJSValueHandle,
  to value: QJSValueHandle,
  in context: QJSContextHandle,
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

// MARK: - Context-side driver conformance (Stage 2B)

extension QJSContextHandle: JSContextPropertyDriver {
  package typealias PropertyStringKeyHandle = QJSPropertyStringKeyHandle

  package func makePropertyStringKeyHandle(_ value: String)
    -> QJSPropertyStringKeyHandle?
  {
    QJSEngine.makePropertyStringKeyHandle(value, in: self)
  }

  package func makePropertyStringKeyHandle(_ value: StaticString)
    -> QJSPropertyStringKeyHandle?
  {
    QJSEngine.makePropertyStringKeyHandle(value, in: self)
  }

  package func isPropertyStringKeyHandleCompatibleWithContext(
    _ key: QJSPropertyStringKeyHandle
  ) -> Bool {
    QJSEngine.isPropertyStringKeyHandleCompatibleWithContext(key, in: self)
  }

  package func makeStringValueHandle(
    fromPropertyStringKey key: QJSPropertyStringKeyHandle
  ) -> QJSOwnedValueHandle? {
    QJSEngine.makeStringValueHandle(fromPropertyStringKey: key, in: self)
  }

  package func propertyNamesForHandle(on object: QJSValueHandle) -> [String]? {
    QJSEngine.propertyNamesForHandle(on: object, in: self)
  }

  package func getStaticStringPropertyHandle(
    _ key: StaticString,
    on object: QJSValueHandle
  ) -> JSResult<QJSValueHandle>? {
    QJSEngine.getStaticStringPropertyHandle(key, on: object, in: self)
  }

  package func setStaticStringPropertyHandle(
    _ key: StaticString,
    on object: QJSValueHandle,
    to value: QJSValueHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    QJSEngine.setStaticStringPropertyHandle(
      key,
      on: object,
      to: value,
      in: self,
      attributes: attributes
    )
  }

  package func getPropertyStringKeyHandle(
    _ key: QJSPropertyStringKeyHandle,
    on object: QJSValueHandle
  ) -> JSResult<QJSValueHandle>? {
    QJSEngine.getPropertyStringKeyHandle(key, on: object, in: self)
  }

  package func setPropertyStringKeyHandle(
    _ key: QJSPropertyStringKeyHandle,
    on object: QJSValueHandle,
    to value: QJSValueHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    QJSEngine.setPropertyStringKeyHandle(
      key,
      on: object,
      to: value,
      in: self,
      attributes: attributes
    )
  }

  package func getValuePropertyHandle(
    _ key: QJSValueHandle,
    on object: QJSValueHandle
  ) -> JSResult<QJSValueHandle>? {
    QJSEngine.getValuePropertyHandle(key, on: object, in: self)
  }

  package func getIndexPropertyHandle(
    at index: UInt32,
    on object: QJSValueHandle
  ) -> JSResult<QJSValueHandle>? {
    QJSEngine.getIndexPropertyHandle(at: index, on: object, in: self)
  }

  package func setValuePropertyHandle(
    _ key: QJSValueHandle,
    on object: QJSValueHandle,
    to value: QJSValueHandle,
    attributes: JSHostMemberAttributes
  ) -> Bool {
    QJSEngine.setValuePropertyHandle(
      key,
      on: object,
      to: value,
      in: self,
      attributes: attributes
    )
  }

  package func setIndexPropertyHandle(
    at index: UInt32,
    on object: QJSValueHandle,
    to value: QJSValueHandle
  ) -> Bool {
    QJSEngine.setIndexPropertyHandle(at: index, on: object, to: value, in: self)
  }

  package func hasStaticStringPropertyHandle(
    _ key: StaticString,
    on object: QJSValueHandle
  ) -> Bool? {
    QJSEngine.hasStaticStringPropertyHandle(key, on: object, in: self)
  }

  package func hasPropertyStringKeyHandle(
    _ key: QJSPropertyStringKeyHandle,
    on object: QJSValueHandle
  ) -> Bool? {
    QJSEngine.hasPropertyStringKeyHandle(key, on: object, in: self)
  }

  package func hasValuePropertyHandle(
    _ key: QJSValueHandle,
    on object: QJSValueHandle
  ) -> Bool? {
    QJSEngine.hasValuePropertyHandle(key, on: object, in: self)
  }

  package func deleteStaticStringPropertyHandle(
    _ key: StaticString,
    on object: QJSValueHandle
  ) -> Bool {
    QJSEngine.deleteStaticStringPropertyHandle(key, on: object, in: self)
  }

  package func deletePropertyStringKeyHandle(
    _ key: QJSPropertyStringKeyHandle,
    on object: QJSValueHandle
  ) -> Bool {
    QJSEngine.deletePropertyStringKeyHandle(key, on: object, in: self)
  }

  package func deleteValuePropertyHandle(
    _ key: QJSValueHandle,
    on object: QJSValueHandle
  ) -> Bool {
    QJSEngine.deleteValuePropertyHandle(key, on: object, in: self)
  }
}
