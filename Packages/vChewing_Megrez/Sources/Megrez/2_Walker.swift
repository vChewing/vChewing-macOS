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
  /// - Returns: 爬軌結果＋該過程是否順利執行。
  @discardableResult mutating func walk() -> (walkedNodes: [Megrez.Node], succeeded: Bool) {
    var result = [Megrez.Node]()
    defer { walkedNodes = result }
    guard !spans.isEmpty else { return (result, true) }

    var vertexSpans: [[Int: Vertex]] = spans.map(\.asVertexSpan)

    let terminal = Vertex(node: .init(keyArray: ["_TERMINAL_"]))
    var root = Vertex(node: .init(keyArray: ["_ROOT_"]))
    root.distance = 0

    vertexSpans.enumerated().forEach { location, vertexSpan in
      vertexSpan.values.forEach { vertex in
        let nextVertexPosition = location + vertex.node.spanLength
        if nextVertexPosition == vertexSpans.count {
          vertex.edges.append(terminal)
          return
        }
        vertexSpans[nextVertexPosition].values.forEach { vertex.edges.append($0) }
      }
    }

    root.edges.append(contentsOf: vertexSpans[0].values)

    topologicalSort(root: &root).reversed().forEach { neta in
      neta.edges.indices.forEach { neta.relax(target: &neta.edges[$0]) }
    }

    var iterated = terminal
    var walked = [Megrez.Node]()
    var totalLengthOfKeys = 0

    while let itPrev = iterated.prev {
      walked.append(itPrev.node)
      iterated = itPrev
      totalLengthOfKeys += iterated.node.spanLength
    }

    // 清理內容，否則會有記憶體洩漏。
    vertexSpans.removeAll()
    iterated.destroy()
    root.destroy()
    terminal.destroy()

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

extension Megrez.SpanUnit {
  /// 將當前幅位單元由節點辭典轉為頂點辭典。
  var asVertexSpan: [Int: Megrez.Compositor.Vertex] {
    var result = [Int: Megrez.Compositor.Vertex]()
    forEach { theKey, theValue in
      result[theKey] = .init(node: theValue)
    }
    return result
  }
}
