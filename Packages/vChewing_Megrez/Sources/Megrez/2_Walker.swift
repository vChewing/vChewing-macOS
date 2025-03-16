// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

extension Megrez.Compositor {
  /// 爬軌函式，會以 Dijkstra 算法更新當前組字器的 walkedNodes。
  ///
  /// 該算法會在圖中尋找具有最高分數的路徑，即最可能的字詞組合。
  ///
  /// 該算法所依賴的 HybridPriorityQueue 針對 Sandy Bridge 經過最佳化處理，
  /// 使得該算法在 Sandy Bridge CPU 的電腦上比 DAG 算法擁有更優的效能。
  ///
  /// - Returns: 爬軌結果（已選字詞陣列）。
  @discardableResult
  public func walk() -> [Megrez.Node] {
    walkedNodes.removeAll()
    guard !spans.isEmpty else { return [] }

    // 初期化資料結構。
    var openSet = HybridPriorityQueue<PrioritizedState>(reversed: true)
    var visited = Set<SearchState>()
    var bestScore = [Int: Double]() // 追蹤每個位置的最佳分數

    // 初期化起始狀態。
    let leadingNode = Megrez.Node(keyArray: ["$LEADING"])
    let start = SearchState(
      node: leadingNode,
      position: 0,
      prev: nil,
      distance: 0
    )
    openSet.enqueue(PrioritizedState(state: start))
    bestScore[0] = 0

    // 追蹤最佳結果。
    var bestFinalState: SearchState?
    var bestFinalScore = Double(Int32.min)

    // 主要 Dijkstra 迴圈。
    while !openSet.isEmpty {
      guard let current = openSet.dequeue()?.state else { break }

      // 如果已經造訪過具有更好分數的狀態，則跳過。
      if visited.contains(current) { continue }
      visited.insert(current)

      // 檢查是否已到達終點。
      if current.position >= keys.count {
        if current.distance > bestFinalScore {
          bestFinalScore = current.distance
          bestFinalState = current
        }
        continue
      }

      // 處理下一個可能的節點。
      for (length, nextNode) in spans[current.position] {
        let nextPos = current.position + length

        // 計算新的權重分數。
        let newScore = current.distance + nextNode.score

        // 如果該位置已有更優的權重分數，則跳過。
        guard (bestScore[nextPos] ?? .init(Int32.min)) < newScore else { continue }

        let nextState = SearchState(
          node: nextNode,
          position: nextPos,
          prev: current,
          distance: newScore
        )

        bestScore[nextPos] = newScore
        openSet.enqueue(PrioritizedState(state: nextState))
      }
    }

    // 從最佳終止狀態重建路徑。
    guard let finalState = bestFinalState else { return [] }
    var pathNodes: [Megrez.Node] = []
    var current: SearchState? = finalState

    while let state = current {
      // 排除起始和結束的虛擬節點。
      if state.node !== leadingNode {
        pathNodes.insert(state.node, at: 0)
      }
      current = state.prev
      // 備註：此處不需要手動 ASAN，因為沒有參據循環（Retain Cycle）。
    }
    walkedNodes = pathNodes.map(\.copy)
    return walkedNodes
  }
}

// MARK: - 搜尋狀態相關定義

extension Megrez.Compositor {
  /// 用於追蹤搜尋過程中的狀態。
  private final class SearchState: Hashable {
    // MARK: Lifecycle

    /// 初期化搜尋狀態。
    /// - Parameters:
    ///   - node: 當前節點。
    ///   - position: 在輸入串中的位置。
    ///   - prev: 前一個狀態。
    ///   - distance: 到達此狀態的累計分數。
    init(
      node: Megrez.Node,
      position: Int,
      prev: SearchState?,
      distance: Double = Double(Int.min)
    ) {
      self.node = node
      self.position = position
      self.prev = prev
      self.distance = distance
    }

    // MARK: Internal

    unowned let node: Megrez.Node // 當前節點
    let position: Int // 在輸入串中的位置
    unowned let prev: SearchState? // 前一個狀態
    var distance: Double // 累計分數

    // MARK: - Hashable 協定實作

    static func == (lhs: SearchState, rhs: SearchState) -> Bool {
      lhs.node === rhs.node && lhs.position == rhs.position
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(node)
      hasher.combine(position)
    }
  }

  /// 用於優先序列的狀態包裝結構
  private struct PrioritizedState: Comparable {
    let state: SearchState

    // MARK: - Comparable 協定實作

    static func < (lhs: Self, rhs: Self) -> Bool {
      lhs.state.distance < rhs.state.distance
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.state == rhs.state
    }
  }
}
