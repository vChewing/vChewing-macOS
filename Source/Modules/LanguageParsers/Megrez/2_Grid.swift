// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Lukhnos Liu's C++ library "Gramambular" (MIT License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

extension Megrez {
  /// 軌格，會被組字器作為原始型別來繼承。
  public class Grid {
    /// 軌格增減行為。
    public enum ResizeBehavior { case expand, shrink }
    /// 幅位陣列。
    private(set) var spans: [Megrez.SpanUnit]

    /// 該軌格內可以允許的最大幅位長度。
    private(set) var maxBuildSpanLength = 10

    /// 公開：軌格的寬度，也就是其內的幅位陣列當中的幅位數量。
    public var width: Int { spans.count }

    /// 公開：軌格是否為空。
    public var isEmpty: Bool { spans.isEmpty }

    /// 初期化轨格。
    public init(spanLengthLimit: Int = 10) {
      maxBuildSpanLength = spanLengthLimit
      spans = [Megrez.SpanUnit]()
    }

    /// 自我清空該軌格的內容。
    public func clear() {
      spans.removeAll()
    }

    /// 往該軌格的指定位置插入指定幅位長度的指定節點。
    /// - Parameters:
    ///   - node: 節點。
    ///   - location: 位置。
    ///   - spanLength: 給定的幅位長度。
    public func insertNode(node: Node, location: Int, spanLength: Int) {
      let location = abs(location)  // 防呆
      let spanLength = abs(spanLength)  // 防呆
      if location >= spans.count {
        let diff = location - spans.count + 1
        for _ in 0..<diff {
          spans.append(SpanUnit())
        }
      }
      spans[location].insert(node: node, length: spanLength)
    }

    /// 給定索引鍵、位置、幅位長度，在該軌格內確認是否有對應的節點存在。
    /// - Parameters:
    ///   - location: 位置。
    ///   - spanLength: 給定的幅位長度。
    ///   - key: 索引鍵。
    public func hasMatchedNode(location: Int, spanLength: Int, key: String) -> Bool {
      let location = abs(location)  // 防呆
      let spanLength = abs(spanLength)  // 防呆
      if location > spans.count {
        return false
      }

      let n = spans[location].nodeOf(length: spanLength)
      return n != nil && key == n?.key
    }

    /// 在該軌格的指定位置擴增或減少一個幅位。
    /// - Parameters:
    ///   - location: 位置。
    public func resizeGridByOneAt(location: Int, to behavior: ResizeBehavior) {
      let location = max(0, min(width, location))  // 防呆
      switch behavior {
        case .expand:
          spans.insert(SpanUnit(), at: location)
          if [spans.count, 0].contains(location) { return }
        case .shrink:
          if location >= spans.count { return }
          spans.remove(at: location)
      }
      for i in 0..<location {
        // 處理掉被損毀的或者重複的幅位。
        spans[i].dropNodesBeyond(length: location - i)
      }
    }

    /// 給定位置，枚舉出所有在這個位置開始的節點。
    /// - Parameters:
    ///   - location: 位置。
    public func nodesBeginningAt(location: Int) -> [NodeAnchor] {
      let location = abs(location)  // 防呆
      var results = [NodeAnchor]()
      if location >= spans.count { return results }
      // 此時 spans 必然不為空，因為 location 不可能小於 0。
      let span = spans[location]
      for i in 1...maxBuildSpanLength {
        if let np = span.nodeOf(length: i) {
          results.append(.init(node: np))
        }
      }
      return results  // 已證實不會有空節點產生。
    }

    /// 給定位置，枚舉出所有在這個位置結尾的節點。
    /// - Parameters:
    ///   - location: 位置。
    public func nodesEndingAt(location: Int) -> [NodeAnchor] {
      let location = abs(location)  // 防呆
      var results = [NodeAnchor]()
      if spans.isEmpty || location > spans.count { return results }
      for i in 0..<location {
        let span = spans[i]
        if i + span.maxLength < location { continue }
        if let np = span.nodeOf(length: location - i) {
          results.append(.init(node: np))
        }
      }
      return results  // 已證實不會有空節點產生。
    }

    /// 給定位置，枚舉出所有在這個位置結尾、或者橫跨該位置的節點。
    /// - Parameters:
    ///   - location: 位置。
    public func nodesCrossingOrEndingAt(location: Int) -> [NodeAnchor] {
      let location = abs(location)  // 防呆
      var results = [NodeAnchor]()
      if spans.isEmpty || location > spans.count { return results }
      for i in 0..<location {
        let span = spans[i]
        if i + span.maxLength < location { continue }
        for j in 1...span.maxLength {
          if i + j < location { continue }
          if let np = span.nodeOf(length: j) {
            results.append(.init(node: np))
          }
        }
      }
      return results  // 已證實不會有空節點產生。
    }

    /// 給定位置，枚舉出所有在這個位置結尾或開頭或者橫跨該位置的節點。
    ///
    /// ⚠︎ 注意：排序可能失真。
    /// - Parameters:
    ///   - location: 位置。
    public func nodesOverlappedAt(location: Int) -> [NodeAnchor] {
      Array(Set(nodesBeginningAt(location: location) + nodesCrossingOrEndingAt(location: location)))
    }

    /// 使用給定的候選字字串，將給定位置的節點的候選字詞改為與給定的字串一致的候選字詞。
    ///
    /// 該函式可以僅用作過程函式，但準確度不如用於處理候選字鍵值配對的 fixNodeWithCandidate()。
    /// - Parameters:
    ///   - location: 位置。
    ///   - value: 給定字串。
    @discardableResult public func fixNodeWithCandidateLiteral(_ value: String, at location: Int) -> NodeAnchor {
      let location = abs(location)  // 防呆
      var node = NodeAnchor()
      for theAnchor in nodesCrossingOrEndingAt(location: location) {
        let candidates = theAnchor.node.candidates
        // 將該位置的所有節點的候選字詞鎖定狀態全部重設。
        theAnchor.node.resetCandidate()
        for (i, candidate) in candidates.enumerated() {
          if candidate.value == value {
            theAnchor.node.selectCandidateAt(index: i)
            node = theAnchor
            break
          }
        }
      }
      return node
    }

    /// 使用給定的候選字鍵值配對，將給定位置的節點的候選字詞改為與給定的字串一致的候選字詞。
    ///
    /// 該函式可以僅用作過程函式。
    /// - Parameters:
    ///   - location: 位置。
    ///   - value: 給定候選字鍵值配對。
    @discardableResult public func fixNodeWithCandidate(_ pair: KeyValuePaired, at location: Int) -> NodeAnchor {
      let location = abs(location)  // 防呆
      var node = NodeAnchor()
      for theAnchor in nodesCrossingOrEndingAt(location: location) {
        let candidates = theAnchor.node.candidates
        // 將該位置的所有節點的候選字詞鎖定狀態全部重設。
        theAnchor.node.resetCandidate()
        for (i, candidate) in candidates.enumerated() {
          if candidate == pair {
            theAnchor.node.selectCandidateAt(index: i)
            node = theAnchor
            break
          }
        }
      }
      return node
    }

    /// 將給定位置的節點的與給定的字串一致的候選字詞的權重複寫為給定權重數值。
    /// - Parameters:
    ///   - location: 位置。
    ///   - value: 給定字串。
    ///   - overridingScore: 給定權重數值。
    public func overrideNodeScoreForSelectedCandidate(location: Int, value: String, overridingScore: Double) {
      let location = abs(location)  // 防呆
      for theAnchor in nodesOverlappedAt(location: location) {
        let candidates = theAnchor.node.candidates
        // 將該位置的所有節點的候選字詞鎖定狀態全部重設。
        theAnchor.node.resetCandidate()
        for (i, candidate) in candidates.enumerated() {
          if candidate.value == value {
            theAnchor.node.selectFloatingCandidateAt(index: i, score: overridingScore)
            break
          }
        }
      }
    }
  }
}

// MARK: - DumpDOT-related functions.

extension Megrez.Grid {
  /// 生成用以交給 GraphViz 診斷的資料檔案內容，純文字。
  public var dumpDOT: String {
    var strOutput = "digraph {\ngraph [ rankdir=LR ];\nBOS;\n"
    for (p, span) in spans.enumerated() {
      for ni in 0...(span.maxLength) {
        guard let np = span.nodeOf(length: ni) else { continue }
        if p == 0 {
          strOutput += "BOS -> \(np.currentPair.value);\n"
        }
        strOutput += "\(np.currentPair.value);\n"
        if (p + ni) < spans.count {
          let destinationSpan = spans[p + ni]
          for q in 0...(destinationSpan.maxLength) {
            guard let dn = destinationSpan.nodeOf(length: q) else { continue }
            strOutput += np.currentPair.value + " -> " + dn.currentPair.value + ";\n"
          }
        }
        guard (p + ni) == spans.count else { continue }
        strOutput += np.currentPair.value + " -> EOS;\n"
      }
    }
    strOutput += "EOS;\n}\n"
    return strOutput
  }
}
