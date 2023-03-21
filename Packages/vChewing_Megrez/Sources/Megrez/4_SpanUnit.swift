// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

public extension Megrez {
  /// 幅位乃指一組共享起點的節點。其實是個辭典：[幅位長度: 節點]。
  typealias SpanUnit = [Int: Node]
}

public extension Megrez.SpanUnit {
  /// 幅位乃指一組共享起點的節點。其實是個辭典：[幅位長度: 節點]。
  /// - Remark: 因為 Node 不是 Struct，所以會在 Compositor 被拷貝的時候無法被真實複製。
  /// 這樣一來，Compositor 複製品當中的 Node 的變化會被反應到原先的 Compositor 身上。
  /// 這在某些情況下會造成意料之外的混亂情況，所以需要引入一個拷貝用的建構子。
  init(SpanUnit target: Megrez.SpanUnit) {
    self.init()
    target.forEach { theKey, theValue in
      self[theKey] = theValue.copy
    }
  }

  /// 該幅位的硬拷貝。
  var hardCopy: Megrez.SpanUnit { .init(SpanUnit: self) }

  // MARK: - Dynamic Variables

  /// 該幅位單元內的所有節點當中持有最長幅位的節點長度。
  /// 該變數受該幅位的自身操作函式而被動更新。
  var maxLength: Int { keys.max() ?? 0 }

  /// （該變數為捷徑，代傳 Megrez.Compositor.maxSpanLength。）
  private var maxSpanLength: Int { Megrez.Compositor.maxSpanLength }
  /// 該幅位單元內的節點的幅位長度上限。
  private var allowedLengths: ClosedRange<Int> { 1 ... maxSpanLength }

  // MARK: - Functions

  /// 往該幅位塞入一個節點。
  /// - Remark: 這個函式用來防呆。一般情況下用不到。
  /// - Parameter node: 要塞入的節點。
  /// - Returns: 該操作是否成功執行。
  @discardableResult mutating func addNode(node: Megrez.Node) -> Bool {
    guard allowedLengths.contains(node.spanLength) else { return false }
    self[node.spanLength] = node
    return true
  }

  /// 丟掉任何不小於給定幅位長度的節點。
  /// - Remark: 這個函式用來防呆。一般情況下用不到。
  /// - Parameter length: 給定的幅位長度。
  /// - Returns: 該操作是否成功執行。
  @discardableResult mutating func dropNodesOfOrBeyond(length: Int) -> Bool {
    guard allowedLengths.contains(length) else { return false }
    let length = Swift.min(length, maxSpanLength)
    (length ... maxSpanLength).forEach { self[$0] = nil }
    return true
  }
}

// MARK: - Related Compositor Implementations.

extension Megrez.Compositor {
  /// 找出所有與該位置重疊的節點。其返回值為一個節錨陣列（包含節點、以及其起始位置）。
  /// - Parameter location: 游標位置。
  /// - Returns: 一個包含所有與該位置重疊的節點的陣列。
  public func fetchOverlappingNodes(at givenLocation: Int) -> [(location: Int, node: Megrez.Node)] {
    var results = [(location: Int, node: Megrez.Node)]()
    let givenLocation = max(0, min(givenLocation, keys.count - 1))
    guard !spans.isEmpty else { return results }

    // 先獲取該位置的所有單字節點。
    (1 ... max(spans[givenLocation].maxLength, 1)).forEach { theSpanLength in
      guard let node = spans[givenLocation][theSpanLength] else { return }
      Self.insertAnchor(spanIndex: givenLocation, node: node, to: &results)
    }

    // 再獲取以當前位置結尾或開頭的節點。
    let begin: Int = givenLocation - min(givenLocation, Megrez.Compositor.maxSpanLength - 1)
    (begin ..< givenLocation).forEach { theLocation in
      let (A, B): (Int, Int) = (givenLocation - theLocation + 1, spans[theLocation].maxLength)
      guard A <= B else { return }
      (A ... B).forEach { theLength in
        guard let node = spans[theLocation][theLength] else { return }
        Self.insertAnchor(spanIndex: theLocation, node: node, to: &results)
      }
    }

    return results
  }

  /// 要在 fetchOverlappingNodes() 內使用的一個工具函式。
  private static func insertAnchor(
    spanIndex location: Int, node: Megrez.Node,
    to targetContainer: inout [(location: Int, node: Megrez.Node)]
  ) {
    guard !node.keyArray.joined().isEmpty else { return }
    let anchor = (location: location, node: node)
    for i in 0 ... targetContainer.count {
      guard !targetContainer.isEmpty else { break }
      guard targetContainer[i].node.spanLength <= anchor.node.spanLength else { continue }
      targetContainer.insert(anchor, at: i)
      return
    }
    guard targetContainer.isEmpty else { return }
    targetContainer.append(anchor)
  }
}
