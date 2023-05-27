// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

public extension Megrez.Compositor {
  /// 爬軌函式，會更新當前組字器的 walkedNodes。
  ///
  /// 找到軌格陣圖內權重最大的路徑。該路徑代表了可被觀測到的最可能的隱藏事件鏈。
  /// 這裡使用 Cormen 在 2001 年出版的教材當中提出的「有向無環圖的最短路徑」的
  /// 算法來計算這種路徑。不過，這裡不是要計算距離最短的路徑，而是計算距離最長
  /// 的路徑（所以要找最大的權重），因為在對數概率下，較大的數值意味著較大的概率。
  /// 對於 `G = (V, E)`，該算法的運行次數為 `O(|V|+|E|)`，其中 `G` 是一個有向無環圖。
  /// 這意味著，即使軌格很大，也可以用很少的算力就可以爬軌。
  ///
  /// - Remark: 利用該數學方法進行輸入法智能組句的（已知可考的）最開始的案例是
  /// 郭家寶（ByVoid）的《[基於統計語言模型的拼音輸入法](https://byvoid.com/zht/blog/slm_based_pinyin_ime/) 》；
  /// 再後來則是 2022 年中時期劉燈的 Gramambular 2 組字引擎。
  /// - Returns: 爬軌結果＋該過程是否順利執行。
  @discardableResult mutating func walk() -> [Megrez.Node] {
    defer { Self.reinitVertexNetwork() }
    sortAndRelax()
    guard !spans.isEmpty else { return [] }
    var iterated: Megrez.Node? = Megrez.Node.leadingNode
    walkedNodes.removeAll()
    while let itPrev = iterated?.prev {
      // 此處必須得是 Copy，讓組字器外部對此的操作影響不到組字器內部的節點。
      walkedNodes.insert(itPrev.copy, at: 0)
      iterated = itPrev
    }
    iterated?.destroyVertex()
    iterated = nil
    walkedNodes.removeFirst()
    return walkedNodes
  }

  /// 先進行位相幾何排序、再卸勁。
  internal func sortAndRelax() {
    Self.reinitVertexNetwork()
    guard !spans.isEmpty else { return }
    Megrez.Node.trailingNode.distance = 0
    spans.enumerated().forEach { location, theSpan in
      theSpan.values.forEach { theNode in
        let nextVertexPosition = location + theNode.spanLength
        if nextVertexPosition == spans.count {
          theNode.edges.append(.leadingNode)
          return
        }
        spans[nextVertexPosition].values.forEach { theNode.edges.append($0) }
      }
    }
    Megrez.Node.trailingNode.edges.append(contentsOf: spans[0].values)
    Self.topologicalSort().reversed().forEach { neta in
      neta.edges.indices.forEach { Self.relax(u: neta, v: &neta.edges[$0]) }
    }
  }

  /// 摧毀所有與共用起始虛擬節點有牽涉的節點自身的 Vertex 特性資料。
  internal static func reinitVertexNetwork() {
    Megrez.Node.trailingNode.destroyVertex()
    Megrez.Node.leadingNode.destroyVertex()
  }

  /// 對持有單個根頂點的有向無環圖進行位相幾何排序（topological
  /// sort）、且將排序結果以頂點陣列的形式給出。
  ///
  /// 這裡使用我們自己的堆棧和狀態定義實現了一個非遞迴版本，
  /// 這樣我們就不會受到當前線程的堆棧大小的限制。以下是等價的原始算法。
  /// ```
  ///  func topologicalSort(node: Node) {
  ///    node.edges.forEach { nodeNode in
  ///      if !nodeNode.topologicallySorted {
  ///        dfs(nodeNode, result)
  ///        nodeNode.topologicallySorted = true
  ///      }
  ///      result.append(nodeNode)
  ///    }
  ///  }
  /// ```
  /// 至於其遞迴版本，則類似於 Cormen 在 2001 年的著作「Introduction to Algorithms」當中的樣子。
  /// - Returns: 排序結果（頂點陣列）。
  private static func topologicalSort() -> [Megrez.Node] {
    class State {
      var iterIndex: Int
      let node: Megrez.Node
      init(node: Megrez.Node, iterIndex: Int = 0) {
        self.node = node
        self.iterIndex = iterIndex
      }
    }
    var result = [Megrez.Node]()
    var stack = [State]()
    stack.append(.init(node: .trailingNode))
    while !stack.isEmpty {
      let state = stack[stack.count - 1]
      let theNode = state.node
      if state.iterIndex < state.node.edges.count {
        let newNode = state.node.edges[state.iterIndex]
        state.iterIndex += 1
        if !newNode.topologicallySorted {
          stack.append(.init(node: newNode))
          continue
        }
      }
      theNode.topologicallySorted = true
      result.append(theNode)
      stack.removeLast()
    }
    return result
  }

  /// 卸勁函式。
  ///
  /// 「卸勁 (relax)」一詞出自 Cormen 在 2001 年的著作「Introduction to Algorithms」的 585 頁。
  /// - Remark: 自己就是參照頂點 (u)，會在必要時成為 target (v) 的前述頂點。
  /// - Parameters:
  ///   - u: 基準頂點。
  ///   - v: 要影響的頂點。
  private static func relax(u: Megrez.Node, v: inout Megrez.Node) {
    // 從 u 到 w 的距離，也就是 v 的權重。
    let w: Double = v.score
    // 這裡計算最大權重：
    // 如果 v 目前的距離值小於「u 的距離值＋w（w 是 u 到 w 的距離，也就是 v 的權重）」，
    // 我們就更新 v 的距離及其前述頂點。
    guard v.distance < u.distance + w else { return }
    v.distance = u.distance + w
    v.prev = u
  }
}
