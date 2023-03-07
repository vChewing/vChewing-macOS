// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

extension Megrez.Compositor {
  /// 幅位單元乃指一組共享起點的節點。
  public class SpanUnit {
    /// 節點陣列。每個位置上的節點可能是 nil。
    public var nodes: [Int: Node] = [:]
    /// 該幅位單元內的所有節點當中持有最長幅位的節點長度。
    /// 該變數受該幅位的自身操作函式而被動更新。
    public var maxLength: Int { nodes.keys.max() ?? 0 }

    /// （該變數為捷徑，代傳 Megrez.Compositor.maxSpanLength。）
    private var maxSpanLength: Int { Megrez.Compositor.maxSpanLength }
    /// 該幅位單元內的節點的幅位長度上限。
    private var allowedLengths: ClosedRange<Int> { 1 ... maxSpanLength }

    /// 幅位乃指一組共享起點的節點。
    public init() {
      clear()
    }

    /// 清除該幅位單元的全部的節點，且重設最長節點長度為 0，然後再在節點陣列內預留空位。
    public func clear() {
      nodes.removeAll()
    }

    /// 往該幅位塞入一個節點。
    /// - Parameter node: 要塞入的節點。
    /// - Returns: 該操作是否成功執行。
    @discardableResult public func append(node: Node) -> Bool {
      guard allowedLengths.contains(node.spanLength) else { return false }
      nodes[node.spanLength] = node
      return true
    }

    /// 丟掉任何與給定節點完全雷同的節點。
    /// - Remark: Swift 不像 C# 那樣有容量鎖定型陣列，
    /// 對某個位置的內容的刪除行為都可能會導致其它內容錯位、繼發其它不可知故障。
    /// 於是就提供了這個專門的工具函式。
    /// - Parameter node: 要參照的節點。
    public func nullify(node givenNode: Node) {
      let spanLength = givenNode.spanLength
      nodes[spanLength] = nil
    }

    /// 丟掉任何不小於給定幅位長度的節點。
    /// - Parameter length: 給定的幅位長度。
    /// - Returns: 該操作是否成功執行。
    @discardableResult public func dropNodesOfOrBeyond(length: Int) -> Bool {
      guard allowedLengths.contains(length) else { return false }
      let length = min(length, maxSpanLength)
      (length ... maxSpanLength).forEach { nodes[$0] = nil }
      return true
    }

    /// 以給定的幅位長度，在當前幅位單元內找出對應的節點。
    /// - Parameter length: 給定的幅位長度。
    /// - Returns: 查詢結果。
    public func nodeOf(length: Int) -> Node? {
      guard allowedLengths.contains(length) else { return nil }
      return nodes[length]
    }
  }

  // MARK: Internal implementations.

  /// 找出所有與該位置重疊的節點。其返回值為一個節錨陣列（包含節點、以及其起始位置）。
  /// - Parameter location: 游標位置。
  /// - Returns: 一個包含所有與該位置重疊的節點的陣列。
  internal func fetchOverlappingNodes(at location: Int) -> [NodeAnchor] {
    var results = [NodeAnchor]()
    guard !spans.isEmpty, location < spans.count else { return results }

    // 先獲取該位置的所有單字節點。
    for theLocation in 1 ... spans[location].maxLength {
      guard let node = spans[location].nodeOf(length: theLocation) else { continue }
      results.append(.init(node: node, spanIndex: location))
    }

    // 再獲取以當前位置結尾或開頭的節點。
    let begin: Int = location - min(location, Megrez.Compositor.maxSpanLength - 1)
    for theLocation in begin ..< location {
      let (A, B): (Int, Int) = (location - theLocation + 1, spans[theLocation].maxLength)
      guard A <= B else { continue }
      for theLength in A ... B {
        guard let node = spans[theLocation].nodeOf(length: theLength) else { continue }
        results.append(.init(node: node, spanIndex: theLocation))
      }
    }

    return results
  }
}
