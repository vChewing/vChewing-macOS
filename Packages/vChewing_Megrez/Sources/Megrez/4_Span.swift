// Swiftified by (c) 2022 and onwards The vChewing Project (MIT License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

extension Megrez.Compositor {
  /// 幅位乃指一組共享起點的節點。
  public class Span {
    private var nodes: [Node?] = []
    public private(set) var maxLength = 0
    private var maxSpanLength: Int { Megrez.Compositor.maxSpanLength }
    public init() {
      clear()
    }

    public func clear() {
      nodes.removeAll()
      for _ in 0..<maxSpanLength {
        nodes.append(nil)
      }
      maxLength = 0
    }

    /// 往該幅位塞入一個節點。
    /// - Parameter node: 要塞入的節點。
    /// - Returns: 該操作是否成功執行。
    @discardableResult public func append(node: Node) -> Bool {
      guard (1...maxSpanLength).contains(node.spanLength) else {
        return false
      }
      nodes[node.spanLength - 1] = node
      maxLength = max(maxLength, node.spanLength)
      return true
    }

    /// 丟掉任何不小於給定幅位長度的節點。
    /// - Parameter length: 給定的幅位長度。
    /// - Returns: 該操作是否成功執行。
    @discardableResult public func dropNodesOfOrBeyond(length: Int) -> Bool {
      guard (1...maxSpanLength).contains(length) else {
        return false
      }
      for i in length...maxSpanLength {
        nodes[i - 1] = nil
      }
      maxLength = 0
      guard length > 1 else { return false }
      let maxR = length - 2
      for i in 0...maxR {
        if nodes[maxR - i] != nil {
          maxLength = maxR - i + 1
          break
        }
      }
      return true
    }

    public func nodeOf(length: Int) -> Node? {
      guard (1...maxSpanLength).contains(length) else { return nil }
      return nodes[length - 1]
    }
  }

  // MARK: Internal implementations.

  /// 找出所有與該位置重疊的節點。其返回值為一個節錨陣列（包含節點、以及其起始位置）。
  /// - Parameter location: 游標位置。
  /// - Returns: 一個包含所有與該位置重疊的節點的陣列。
  func fetchOverlappingNodes(at location: Int) -> [NodeAnchor] {
    var results = [NodeAnchor]()
    guard !spans.isEmpty, location < spans.count else { return results }

    // 先獲取該位置的所有單字節點。
    for theLocation in 1...spans[location].maxLength {
      guard let node = spans[location].nodeOf(length: theLocation) else { continue }
      results.append(.init(node: node, spanIndex: location))
    }

    // 再獲取以當前位置結尾或開頭的節點。
    let begin: Int = location - min(location, Megrez.Compositor.maxSpanLength - 1)
    for theLocation in begin..<location {
      let (A, B): (Int, Int) = (location - theLocation + 1, spans[theLocation].maxLength)
      guard A <= B else { continue }
      for theLength in A...B {
        guard let node = spans[theLocation].nodeOf(length: theLength) else { continue }
        results.append(.init(node: node, spanIndex: theLocation))
      }
    }

    return results
  }
}
