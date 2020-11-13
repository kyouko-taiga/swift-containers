/// A pool of memory arenas.
public final class MemoryArenaPool<Element> {

  /// Creates a new pool of memory arenas.
  ///
  /// - Parameter arenaCapacity: The capactiy of a single arena.
  public init(arenaCapacity: Int) {
    precondition(arenaCapacity > 0)
    self.arenaCapacity = arenaCapacity
  }

  /// The capacity of a single arena.
  public let arenaCapacity: Int

  /// The arenas of the pool.
  private var arenas: [MemoryArena<Element>] = []

  /// Allocates the memory of a single `Element` instance.
  ///
  /// - Returns: An uninitialized pointer to `Element`.
  ///
  /// - Important: Do **not** deallocate arena pointers outside of the arenas of the pool;
  ///   attempting to do so so will result in undefined behavior. Use the pool's `deallocate(:)`
  ///   method instead.
  public func allocate() -> UnsafeMutablePointer<Element> {
    for arena in arenas {
      if let address = arena.allocate() {
        return address
      }
    }

    arenas.append(MemoryArena(capacity: arenaCapacity))
    return arenas.last!.allocate()!
  }

  /// Deallocates a pointer.
  ///
  /// Calling this method has no effect if `pointer` is not currently allocated or if it does not
  /// point into any arena of the pool.
  ///
  /// - Parameters:
  ///   - pointer: The pointer to deallocate. `pointer` must not be initialized or `Element` must
  ///     be a trivial type.
  ///   - keepingEmptyArenas: Pass `true` to request that the pool avoids releasing empty arenas.
  ///     This can be a useful optimization when you are planning to allocate new objects again.
  ///     The default value is `false`.
  public func deallocate(
    _ pointer: UnsafeMutablePointer<Element>,
    keepingEmptyArenas: Bool = false
  ) {
    for i in 0 ..< arenas.count {
      if arenas[i] ~= pointer {
        arenas[i].deallocate(pointer)
        if !keepingEmptyArenas && arenas[i].isEmpty {
          arenas.remove(at: i)
        }
        break
      }
    }
  }

  /// Returns whether a pointer lies within the bounds of the given arena pool.
  ///
  /// - Parameters:
  ///   - pool: The pool in which the pointer should be contained.
  ///   - pointer: The pointer to check.
  public static func ~= (pool: MemoryArenaPool, pointer: UnsafeMutablePointer<Element>) -> Bool {
    return pool.arenas.contains(where: { arena in arena ~= pointer })
  }

}
