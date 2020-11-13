/// A typed pointer tagged by some value.
///
/// A tagged pointer is an address paired with a tag value, stored in its lower bits. It leverages
/// the fact that the lower `n` bits of an `2ⁿ`-byte aligned pointer are always 0.
///
/// The maximum number of bits available to store the tag value is determined automatically, using
/// `MemoryLayout<Pointee>.alignment`. For instance, an 8-byte alignment will result in 3 bits.
public struct TaggedPointer<Pointee>: RawRepresentable {

  /// Creates a new tagged pointer from a raw address and a tag value.
  ///
  /// - Parameters:
  ///   - address: A pointer.
  ///   - tag: A tag value.
  public init(address: UnsafePointer<Pointee>, tag: Int) {
    let mask = MemoryLayout<Pointee>.alignment - 1
    precondition(tag & mask == tag)
    rawValue = Int(bitPattern: address) | tag
  }

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public private(set) var rawValue: Int

  /// The address stored in this tagged pointer.
  public var address: UnsafeMutablePointer<Pointee>? {
    get {
      let mask = MemoryLayout<Pointee>.alignment - 1
      return UnsafeMutablePointer(bitPattern: rawValue & ~mask)
    }

    set {
      rawValue = Int(bitPattern: newValue) | tag
    }
  }

  /// The tag stored in this tagged pointer.
  public var tag: Int {
    get {
      let mask =  MemoryLayout<Pointee>.alignment - 1
      return rawValue & mask
    }

    set {
      let mask = MemoryLayout<Pointee>.alignment - 1
      precondition(newValue & mask == newValue)
      rawValue = (rawValue & ~mask) | newValue
    }
  }

  /// The instance referenced by this tagged pointer.
  public var pointee: Pointee? {
    return address?.pointee
  }

}

extension TaggedPointer: Hashable {
}
