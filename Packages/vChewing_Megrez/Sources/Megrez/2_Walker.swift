// Swiftified and further development by (c) 2022 and onwards The vChewing Project (MIT License).
// Was initially rebranded from (c) Lukhnos Liu's C++ library "Gramambular 2" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

extension Megrez.Compositor {
  /// 爬軌函式，會更新當前組字器的 walkedNodes。
  ///
  /// 找到軌格陣圖內權重最大的路徑。該路徑代表了可被觀測到的最可能的隱藏事件鏈。
  /// 這裡使用 Cormen 在 2001 年出版的教材當中提出的「有向無環圖的最短路徑」的
  /// 算法來計算這種路徑。不過，這裡不是要計算距離最短的路徑，而是計算距離最長
  /// 的路徑（所以要找最大的權重），因為在對數概率下，較大的數值意味著較大的概率。
  /// 對於 `G = (V, E)`，該算法的運行次數為 `O(|V|+|E|)`，其中 `G` 是一個有向無環圖。
  /// 這意味著，即使軌格很大，也可以用很少的算力就可以爬軌。
  /// - Returns: 爬軌結果＋該過程是否順利執行。
  @discardableResult public mutating func walk() -> (walkedNode: [Node], succeeded: Bool) {
    var result = [Node]()
    defer {
      walkedNodes = result
      updateCursorJumpingTables()
    }
    guard !spans.isEmpty else { return (result, true) }

    var vertexSpans = [[Vertex]]()
    for _ in spans {
      vertexSpans.append(.init())
    }

    for (i, span) in spans.enumerated() {
      for j in 1...span.maxLength {
        if let theNode = span.nodeOf(length: j) {
          vertexSpans[i].append(.init(node: theNode))
        }
      }
    }

    let terminal = Vertex(node: .init(keyArray: ["_TERMINAL_"]))

    for (i, vertexSpan) in vertexSpans.enumerated() {
      for vertex in vertexSpan {
        let nextVertexPosition = i + vertex.node.spanLength
        if nextVertexPosition == vertexSpans.count {
          vertex.edges.append(terminal)
          continue
        }
        for nextVertex in vertexSpans[nextVertexPosition] {
          vertex.edges.append(nextVertex)
        }
      }
    }

    let root = Vertex(node: .init(keyArray: ["_ROOT_"]))
    root.distance = 0
    root.edges.append(contentsOf: vertexSpans[0])

    var ordered: [Vertex] = topologicalSort(root: root)
    for (j, neta) in ordered.reversed().enumerated() {
      for (k, _) in neta.edges.enumerated() {
        relax(u: neta, v: &neta.edges[k])
      }
      ordered[j] = neta
    }

    var walked = [Node]()
    var totalLengthOfKeys = 0
    var iterated = terminal
    while let itPrev = iterated.prev {
      walked.append(itPrev.node)
      iterated = itPrev
      totalLengthOfKeys += iterated.node.spanLength
    }

    guard totalLengthOfKeys == keys.count else {
      print("!!! ERROR A")
      return (result, false)
    }
    guard walked.count >= 2 else {
      print("!!! ERROR B")
      return (result, false)
    }
    walked = walked.reversed()
    walked.removeFirst()
    result = walked
    return (result, true)
  }
}
