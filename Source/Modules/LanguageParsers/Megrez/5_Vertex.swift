// Swiftified by (c) 2022 and onwards The vChewing Project (MIT License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

extension Megrez.Compositor {
  /// 一個「有向無環圖的」的頂點單位。
  ///
  /// 這是一個可變的數據結構，用於有向無環圖的構建和單源最短路徑的計算。
  class Vertex {
    /// 前述頂點。
    public var prev: Vertex?
    /// 自身屬下的頂點陣列。
    public var edges = [Vertex]()
    /// 該變數用於最短路徑的計算。
    ///
    /// 我們實際上是在計算具有最大權重的路徑，因此距離的初始值是負無窮的。
    /// 如果我們要計算最短的權重/距離，我們會將其初期值設為正無窮。
    public var distance = -(Double.infinity)
    /// 在進行進行位相幾何排序時會用到的狀態標記。
    public var topologicallySorted = false
    public var node: Node
    public init(node: Node) {
      self.node = node
    }
  }

  /// 卸勁函式。
  ///
  /// 「卸勁 (relax)」一詞出自 Cormen 在 2001 年的著作「Introduction to Algorithms」的 585 頁。
  /// - Parameters:
  ///   - u: 參照頂點，會在必要時成為 v 的前述頂點。
  ///   - v: 要影響的頂點。
  func relax(u: Vertex, v: inout Vertex) {
    /// 從 u 到 w 的距離，也就是 v 的權重。
    let w: Double = v.node.score
    /// 這裡計算最大權重：
    /// 如果 v 目前的距離值小於「u 的距離值＋w（w 是 u 到 w 的距離，也就是 v 的權重）」，
    /// 我們就更新 v 的距離及其前述頂點。
    if v.distance < u.distance + w {
      v.distance = u.distance + w
      v.prev = u
    }
  }

  typealias VertexSpan = [Vertex]

  /// 對持有單個根頂點的有向無環圖進行位相幾何排序（topological
  /// sort）、且將排序結果以頂點陣列的形式給出。
  ///
  /// 這裡使用我們自己的堆棧和狀態定義實現了一個非遞迴版本，
  /// 這樣我們就不會受到當前線程的堆棧大小的限制。以下是等價的原始算法。
  /// ```
  ///  func topologicalSort(vertex: Vertex) {
  ///    for vertexNode in vertex.edges {
  ///      if !vertexNode.topologicallySorted {
  ///        dfs(vertexNode, result)
  ///        vertexNode.topologicallySorted = true
  ///      }
  ///      result.append(vertexNode)
  ///    }
  ///  }
  /// ```
  /// 至於遞迴版本則類似於 Cormen 在 2001 年的著作「Introduction to Algorithms」當中的樣子。
  /// - Parameter root: 根頂點。
  /// - Returns: 排序結果（頂點陣列）。
  func topologicalSort(root: Vertex) -> [Vertex] {
    class State {
      var iterIndex: Int
      var vertex: Vertex
      init(vertex: Vertex, iterIndex: Int = 0) {
        self.vertex = vertex
        self.iterIndex = iterIndex
      }
    }
    var result = [Vertex]()
    var stack = [State]()
    stack.append(.init(vertex: root))
    while !stack.isEmpty {
      let state = stack[stack.count - 1]
      let theVertex = state.vertex
      if state.iterIndex < state.vertex.edges.count {
        let newVertex = state.vertex.edges[state.iterIndex]
        state.iterIndex += 1
        if !newVertex.topologicallySorted {
          stack.append(.init(vertex: newVertex))
          continue
        }
      }
      theVertex.topologicallySorted = true
      result.append(theVertex)
      stack.removeLast()
    }
    return result
  }
}
