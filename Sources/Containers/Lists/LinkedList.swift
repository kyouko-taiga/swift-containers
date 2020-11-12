public struct LinkedList<Element> {

  public init() {
  }

  public init(_ other: LinkedList<Element>) {
    self.head = other.head
  }

  public init<S>(_ elements: S) where S: Sequence, S.Element == Element {
    var it = elements.makeIterator()
    if let element = it.next() {
      head = Node(element: element, next: nil)
    } else {
      return
    }

    var tail = head
    while let element = it.next() {
      tail!.next = Node(element: element, next: nil)
      tail = tail!.next
    }
  }

  private init(head: Node?) {
    self.head = head
  }

  private var head: Node?

  fileprivate class Node {

    init(element: Element, next: Node?) {
      self.element = element
      self.next = next
    }

    var element: Element

    var next: Node?

    func copy() -> Node {
      return Node(element: element, next: next?.copy())
    }

  }

  /// A Boolean value indicating whether the container is empty.
  public var isEmpty: Bool {
    return head == nil
  }

  /// The number of elements in the container.
  public var count: Int {
    var i = 0
    var current = head

    while current != nil {
      current = current?.next
      i += 1
    }

    return i
  }

  /// The first element of the container.
  public var first: Element? {
    return head?.element
  }

  /// Removes the first element from the container.
  public mutating func popFirst() -> Element? {
    guard let head = self.head
      else { return nil }

    self.head = head.next
    return head.element
  }

  /// Adds an element at the beginning of the list.
  public mutating func prepend(_ newElement: Element) {
    head = Node(element: newElement, next: head)
  }

  /// Adds the elements of a sequence at the beginning of the list.
  public mutating func prepend<S>(contentsOf newElements: S)
    where S: Sequence, S.Element == Element
  {
    let tail = head

    var it = newElements.makeIterator()
    if let element = it.next() {
      head = Node(element: element, next: nil)
    } else {
      return
    }

    var middle = head
    while let element = it.next() {
      middle!.next = Node(element: element, next: nil)
      middle = middle!.next
    }

    middle!.next = tail
  }

  /// Concatenates two singly-linked lists.
  public static func + (lhs: LinkedList, rhs: LinkedList) -> LinkedList {
    guard let head = lhs.head?.copy()
      else { return rhs }
    guard let tail = rhs.head?.copy()
      else { return lhs }

    var middle = head
    while let next = middle.next {
      middle = next
    }
    middle.next = tail
    return LinkedList(head: head)
  }

}

extension LinkedList: Equatable where Element: Equatable {
}

extension LinkedList.Node: Equatable where Element: Equatable {

  static func == (lhs: LinkedList.Node, rhs: LinkedList.Node) -> Bool {
    return (lhs.element == rhs.element) && (lhs.next == rhs.next)
  }

}

extension LinkedList: Hashable where Element: Hashable {
}

extension LinkedList.Node: Hashable where Element: Hashable {

  func hash(into hasher: inout Hasher) {
    hasher.combine(element)
    hasher.combine(next)
  }

}

extension LinkedList: Sequence {

  public func makeIterator() -> Iterator {
    return Iterator(node: self.head)
  }

  /// A singly linked list iterator.
  public struct Iterator: IteratorProtocol {

    /// The current node.
    fileprivate var node: LinkedList.Node?

    public mutating func next() -> Element? {
      if let n = node {
        let element = n.element
        node = n.next
        return element
      } else {
        return nil
      }
    }

  }

}

extension LinkedList: ExpressibleByArrayLiteral {

  public init(arrayLiteral elements: Element...) {
    self.init(elements)
  }

}

extension LinkedList: CustomStringConvertible {

  public var description: String {
    return String(describing: Array(self))
  }

}
