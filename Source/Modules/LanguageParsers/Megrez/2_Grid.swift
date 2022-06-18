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
  /// 軌格。
  public class Grid {
    /// 幅位陣列。
    private var mutSpans: [Megrez.Span]

    /// 該幅位內可以允許的最大詞長。
    private var mutMaxBuildSpanLength = 10

    /// 公開：該軌格內可以允許的最大幅位長度。
    public var maxBuildSpanLength: Int { mutMaxBuildSpanLength }

    /// 公開：軌格的寬度，也就是其內的幅位陣列當中的幅位數量。
    public var width: Int { mutSpans.count }

    /// 公開：軌格是否為空。
    public var isEmpty: Bool { mutSpans.isEmpty }

    /// 初期化轨格。
    public init(spanLength: Int = 10) {
      mutMaxBuildSpanLength = spanLength
      mutSpans = [Megrez.Span]()
    }

    /// 自我清空該軌格的內容。
    public func clear() {
      mutSpans.removeAll()
    }

    /// 往該軌格的指定位置插入指定幅位長度的指定節點。
    /// - Parameters:
    ///   - node: 節點。
    ///   - location: 位置。
    ///   - spanningLength: 給定的幅位長度。
    public func insertNode(node: Node, location: Int, spanningLength: Int) {
      let location = abs(location)  // 防呆
      let spanningLength = abs(spanningLength)  // 防呆
      if location >= mutSpans.count {
        let diff = location - mutSpans.count + 1
        for _ in 0..<diff {
          mutSpans.append(Span())
        }
      }
      mutSpans[location].insert(node: node, length: spanningLength)
    }

    /// 給定索引鍵、位置、幅位長度，在該軌格內確認是否有對應的節點存在。
    /// - Parameters:
    ///   - location: 位置。
    ///   - spanningLength: 給定的幅位長度。
    ///   - key: 索引鍵。
    public func hasMatchedNode(location: Int, spanningLength: Int, key: String) -> Bool {
      let location = abs(location)  // 防呆
      let spanningLength = abs(spanningLength)  // 防呆
      if location > mutSpans.count {
        return false
      }

      let n = mutSpans[location].node(length: spanningLength)
      return n != nil && key == n?.key
    }

    /// 在該軌格的指定位置擴增一個幅位。
    /// - Parameters:
    ///   - location: 位置。
    public func expandGridByOneAt(location: Int) {
      let location = abs(location)  // 防呆
      mutSpans.insert(Span(), at: location)
      if location != 0, location != mutSpans.count {
        for i in 0..<location {
          // zaps overlapping spans
          mutSpans[i].removeNodeOfLengthGreaterThan(location - i)
        }
      }
    }

    /// 在該軌格的指定位置減少一個幅位。
    /// - Parameters:
    ///   - location: 位置。
    public func shrinkGridByOneAt(location: Int) {
      let location = abs(location)  // 防呆
      if location >= mutSpans.count {
        return
      }

      mutSpans.remove(at: location)
      for i in 0..<location {
        // zaps overlapping spans
        mutSpans[i].removeNodeOfLengthGreaterThan(location - i)
      }
    }

    /// 給定位置，枚舉出所有在這個位置開始的節點。
    /// - Parameters:
    ///   - location: 位置。
    public func nodesBeginningAt(location: Int) -> [NodeAnchor] {
      let location = abs(location)  // 防呆
      var results = [NodeAnchor]()
      if location < mutSpans.count {  // 此時 mutSpans 必然不為空
        let span = mutSpans[location]
        for i in 1...maxBuildSpanLength {
          if let np = span.node(length: i) {
            results.append(
              NodeAnchor(
                node: np,
                location: location,
                spanningLength: i
              )
            )
          }
        }
      }
      return results
    }

    /// 給定位置，枚舉出所有在這個位置結尾的節點。
    /// - Parameters:
    ///   - location: 位置。
    public func nodesEndingAt(location: Int) -> [NodeAnchor] {
      let location = abs(location)  // 防呆
      var results = [NodeAnchor]()
      if !mutSpans.isEmpty, location <= mutSpans.count {
        for i in 0..<location {
          let span = mutSpans[i]
          if i + span.maximumLength >= location {
            if let np = span.node(length: location - i) {
              results.append(
                NodeAnchor(
                  node: np,
                  location: i,
                  spanningLength: location - i
                )
              )
            }
          }
        }
      }
      return results
    }

    /// 給定位置，枚舉出所有在這個位置結尾、或者橫跨該位置的節點。
    /// - Parameters:
    ///   - location: 位置。
    public func nodesCrossingOrEndingAt(location: Int) -> [NodeAnchor] {
      let location = abs(location)  // 防呆
      var results = [NodeAnchor]()
      if !mutSpans.isEmpty, location <= mutSpans.count {
        for i in 0..<location {
          let span = mutSpans[i]
          if i + span.maximumLength >= location {
            for j in 1...span.maximumLength {
              if i + j < location {
                continue
              }
              if let np = span.node(length: j) {
                results.append(
                  NodeAnchor(
                    node: np,
                    location: i,
                    spanningLength: location - i
                  )
                )
              }
            }
          }
        }
      }
      return results
    }

    /// 將給定位置的節點的候選字詞改為與給定的字串一致的候選字詞。
    ///
    /// 該函式可以僅用作過程函式。
    /// - Parameters:
    ///   - location: 位置。
    ///   - value: 給定字串。
    @discardableResult public func fixNodeSelectedCandidate(location: Int, value: String) -> NodeAnchor {
      let location = abs(location)  // 防呆
      var node = NodeAnchor()
      for nodeAnchor in nodesCrossingOrEndingAt(location: location) {
        guard let theNode = nodeAnchor.node else {
          continue
        }
        let candidates = theNode.candidates
        // 將該位置的所有節點的候選字詞鎖定狀態全部重設。
        theNode.resetCandidate()
        for (i, candidate) in candidates.enumerated() {
          if candidate.value == value {
            theNode.selectCandidateAt(index: i)
            node = nodeAnchor
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
      for nodeAnchor in nodesCrossingOrEndingAt(location: location) {
        guard let theNode = nodeAnchor.node else {
          continue
        }
        let candidates = theNode.candidates
        // 將該位置的所有節點的候選字詞鎖定狀態全部重設。
        theNode.resetCandidate()
        for (i, candidate) in candidates.enumerated() {
          if candidate.value == value {
            theNode.selectFloatingCandidateAt(index: i, score: overridingScore)
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
    for (p, span) in mutSpans.enumerated() {
      for ni in 0...(span.maximumLength) {
        guard let np: Megrez.Node = span.node(length: ni) else {
          continue
        }
        if p == 0 {
          strOutput += "BOS -> \(np.currentKeyValue.value);\n"
        }

        strOutput += "\(np.currentKeyValue.value);\n"

        if (p + ni) < mutSpans.count {
          let destinationSpan = mutSpans[p + ni]
          for q in 0...(destinationSpan.maximumLength) {
            if let dn = destinationSpan.node(length: q) {
              strOutput += np.currentKeyValue.value + " -> " + dn.currentKeyValue.value + ";\n"
            }
          }
        }

        if (p + ni) == mutSpans.count {
          strOutput += np.currentKeyValue.value + " -> EOS;\n"
        }
      }
    }
    strOutput += "EOS;\n}\n"
    return strOutput
  }
}
