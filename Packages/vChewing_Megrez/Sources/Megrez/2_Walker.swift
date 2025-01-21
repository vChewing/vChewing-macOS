// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

extension Megrez.Compositor {
  /// 爬軌函式，會更新當前組字器的 walkedNodes。
  /// - Returns: 爬軌結果＋該過程是否順利執行。
  @discardableResult
  public mutating func walk(useDAG: Bool = false) -> [Megrez.Node] {
    useDAG ? walkUsingDAG() : walkUsingDijkstra()
  }
}

// MARK: - Walker (DAG Vertex-Relax Approach).

extension Megrez.Compositor {
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
  @discardableResult
  public mutating func walkUsingDAG() -> [Megrez.Node] {
    defer { Self.reinitVertexNetwork() }
    walkedNodes.removeAll()
    sortAndRelax()
    guard !spans.isEmpty else { return [] }
    var iterated: Megrez.Node? = Megrez.Node.leadingNode
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

// MARK: - Walker (Dijkstra Approach).

extension Megrez.Compositor {
  /// 爬軌函式，會以 Dijkstra 算法更新當前組字器的 walkedNodes。
  /// - Returns: 爬軌結果＋該過程是否順利執行。
  @discardableResult
  public mutating func walkUsingDijkstra() -> [Megrez.Node] {
    walkedNodes.removeAll()

    var openSet = HybridPriorityQueue<PrioritizedState>()
    var visited = Set<SearchState>()
    var distances: [Int: Double] = [:]

    // 從最開始的節點起算。
    let leadingNode = Megrez.Node(keyArray: ["$LEADING"])
    let start = SearchState(node: leadingNode, position: 0, prev: nil, distance: 0)
    openSet.enqueue(PrioritizedState(state: start, distance: 0))
    distances[0] = 0

    var finalState: SearchState?

    walkingProcess: while !openSet.isEmpty {
      guard let current = openSet.dequeue()?.state else { break }
      guard !visited.contains(current) else { continue }
      visited.insert(current)
      guard current.position < keys.count else {
        finalState = current
        break walkingProcess
      }

      // 取得當前的幅位。
      let currentSpan = spans[current.position]

      // 從當前位置處理每個可能的節點。
      currentSpan.forEach { length, nextNode in
        guard let nextNode = currentSpan[length] else { return }
        let nextPosition = current.position + length
        // 計算新的距離（用負分，反向利用 Dijkstra 找最短捷徑的特性、以尋求最長路徑（分值最高的路徑））。
        let newDistance = current.distance - nextNode.score
        // 如果有找到的話，本次迴圈結束，進入下一次迴圈。
        guard (distances[nextPosition] ?? .infinity) > newDistance else { return }

        let nextState = SearchState(
          node: nextNode,
          position: nextPosition,
          prev: current,
          distance: newDistance
        )

        distances[nextPosition] = newDistance
        openSet.enqueue(PrioritizedState(
          state: nextState,
          distance: newDistance
        ))
      }
    }

    if let finalState = finalState {
      walkedNodes = reconstructPath(from: finalState).dropFirst().map(\.node)
    }

    return walkedNodes
  }
}

extension Megrez.Compositor {
  final private class SearchState: Hashable {
    // MARK: Lifecycle

    init(node: Megrez.Node, position: Int, prev: SearchState?, distance: Double = .infinity) {
      self.node = node
      self.position = position
      self.prev = prev
      self.distance = distance
    }

    // MARK: Internal

    let node: Megrez.Node
    let position: Int
    let prev: SearchState?
    var distance: Double

    static func == (lhs: SearchState, rhs: SearchState) -> Bool {
      lhs.node === rhs.node && lhs.position == rhs.position
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(node)
      hasher.combine(position)
    }
  }

  private struct PrioritizedState: Comparable {
    let state: SearchState
    let distance: Double

    static func < (lhs: PrioritizedState, rhs: PrioritizedState) -> Bool {
      lhs.distance < rhs.distance
    }

    static func == (lhs: PrioritizedState, rhs: PrioritizedState) -> Bool {
      lhs.distance == rhs.distance && lhs.state == rhs.state
    }
  }

  private func reconstructPath(from state: SearchState) -> [SearchState] {
    var path: [SearchState] = []
    var current: SearchState? = state

    while let n = current {
      path.insert(n, at: 0)
      current = n.prev
    }

    return path
  }
}
