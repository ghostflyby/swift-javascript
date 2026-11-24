// MARK: - Shared ArrayBuffer byte storage (S10)
//
// Both engines hand externally allocated, zero-filled or copied bytes to their
// no-copy ArrayBuffer constructor. Allocating, copying, and releasing that
// storage is engine-independent, so it lives in core; each engine only calls
// its own constructor through `adoptArrayBufferBytesNoCopy`.

/// The C deallocator both engines pass to their no-copy buffer constructor.
/// The allocation is a plain `UnsafeMutableRawPointer.allocate`, so the
/// matching release is `deallocate()`.
package let jsArrayBufferBytesDeallocator:
  @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?) -> Void = {
    bytes,
    _ in
    bytes?.deallocate()
  }

/// A zero-filled allocation of `byteLength` bytes. Empty buffers have no
/// storage to hand over, so this returns `nil` for them (the engines accept a
/// nil pointer for a zero-length buffer).
package func allocateZeroedArrayBufferBytes(byteLength: Int) -> UnsafeMutableRawPointer? {
  guard byteLength > 0 else {
    return nil
  }

  let pointer = UnsafeMutableRawPointer.allocate(
    byteCount: byteLength,
    alignment: MemoryLayout<UInt8>.alignment
  )
  pointer.initializeMemory(as: UInt8.self, repeating: 0, count: byteLength)
  return pointer
}

/// A copy of `bytes`. The copy runs inside the array's own pointer scope, so
/// no buffer pointer escapes it.
package func allocateArrayBufferBytes(copying bytes: [UInt8]) -> UnsafeMutableRawPointer? {
  guard !bytes.isEmpty else {
    return nil
  }

  let pointer = UnsafeMutableRawPointer.allocate(
    byteCount: bytes.count,
    alignment: MemoryLayout<UInt8>.alignment
  )
  bytes.withUnsafeBytes { source in
    pointer.copyMemory(from: source.baseAddress!, byteCount: bytes.count)
  }
  return pointer
}

/// A copy of an existing raw buffer.
package func allocateArrayBufferBytes(
  copying bytes: UnsafeRawBufferPointer
) -> UnsafeMutableRawPointer? {
  guard let base = bytes.baseAddress, bytes.count > 0 else {
    return nil
  }

  let pointer = UnsafeMutableRawPointer.allocate(
    byteCount: bytes.count,
    alignment: MemoryLayout<UInt8>.alignment
  )
  pointer.copyMemory(from: base, byteCount: bytes.count)
  return pointer
}

/// Hand `bytes` to the engine as a no-copy ArrayBuffer and adopt the creation
/// reference into `context`.
///
/// The engine either takes ownership of the bytes (and calls `bytesDeallocator`
/// when the buffer dies) or rejects the creation. On rejection the engine never
/// took the bytes, so this releases the allocation here — exactly once — and
/// returns `nil`; the caller reports the failure. On success the handle is
/// adopted exactly once by the calling window's arena.
package func adoptArrayBufferBytesNoCopy<C: JSInstantContext & ~Copyable>(
  _ bytes: UnsafeMutableRawPointer?,
  byteLength: Int,
  in context: borrowing C,
  bytesDeallocator:
    @convention(c) (
      UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
    ) -> Void = jsArrayBufferBytesDeallocator
) -> C.Value? where C.ContextHandle: JSContextTypedArrayDriver {
  guard
    let handle = context.driverContextHandle.makeArrayBufferWithBytesNoCopyHandle(
      bytes: bytes,
      byteLength: byteLength,
      bytesDeallocator: bytesDeallocator,
      deallocatorContext: nil
    )
  else {
    bytesDeallocator(bytes, nil)
    return nil
  }

  return context.adoptCreatedHandle(C.ContextHandle.OwnedValueHandle.adopting(handle))
}
