/// A raw pointer tagged by some value.
///
/// A tagged pointer is an address paired with a tag value, stored in its lower bits. It leverages
/// the fact that the lower `n - 1` bits of an n-byte aligned pointer are always 0.
///
/// Addresses are assumed to be properly for the machine's `Int` type. For instance, they must be
/// 8-byte aligned on a 64-bit computer.
public struct TaggedRawPointer: RawRepresentable {

  /// Creates a new tagged raw pointer from a raw address and a tag value.
  ///
  /// - Parameters:
  ///   - address: A pointer. `address` must be properly aligned for `Int`.
  ///   - tag: A tag value.
  public init(address: UnsafeRawPointer, tag: Int) {
    let mask = MemoryLayout<Int>.alignment - 1
    precondition(tag & mask == tag)
    rawValue = Int(bitPattern: address) | tag
  }

  /// Creates a new tagged raw pointer from a tagged pointer.
  ///
  /// - Parameter pointer: A tagged pointer. The address stored in `pointer` must be properly
  ///   aligned for `Int`.
  public init<Pointee>(_ pointer: TaggedPointer<Pointee>) {
    precondition(MemoryLayout<Pointee>.alignment == MemoryLayout<Int>.alignment)
    rawValue = Int(bitPattern: pointer.address) | pointer.tag
  }

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public private(set) var rawValue: Int

  /// The address stored in this tagged pointer.
  public var address: UnsafeMutableRawPointer? {
    get {
      let mask = MemoryLayout<Int>.alignment - 1
      return UnsafeMutableRawPointer(bitPattern: rawValue & ~mask)
    }

    set {
      rawValue = Int(bitPattern: newValue) | tag
    }
  }

  /// The tag stored in this tagged pointer.
  public var tag: Int {
    get {
      let mask = MemoryLayout<Int>.alignment - 1
      return rawValue & mask
    }

    set {
      let mask = MemoryLayout<Int>.alignment - 1
      precondition(newValue & mask == newValue)
      rawValue = (rawValue & ~mask) | newValue
    }
  }

}

extension TaggedRawPointer: Hashable {
}
