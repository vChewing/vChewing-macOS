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

    /// 軌格的寬度，也就是其內的幅位陣列當中的幅位數量。
    var width: Int { mutSpans.count }

    public init() {
      mutSpans = [Megrez.Span]()
    }

    /// 自我清空該軌格的內容。
    public func clear() {
      mutSpans = [Megrez.Span]()
    }

    /// 往該軌格的指定位置插入指定幅位長度的指定節點。
    /// - Parameters:
    ///   - node: 節點。
    ///   - location: 位置。
    ///   - spanningLength: 給定的幅位長度。
    public func insertNode(node: Node, location: Int, spanningLength: Int) {
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
      if location > mutSpans.count {
        return false
      }

      let n = mutSpans[location].node(length: spanningLength)
      return n == nil ? false : key == n?.key
    }

    /// 在該軌格的指定位置擴增一個幅位。
    /// - Parameters:
    ///   - location: 位置。
    public func expandGridByOneAt(location: Int) {
      // 這裡加入 abs 完全是一個防呆設計
      mutSpans.insert(Span(), at: abs(location))
      if location != 0, abs(location) != mutSpans.count {
        for i in 0..<abs(location) {
          // zaps overlapping spans
          mutSpans[i].removeNodeOfLengthGreaterThan(abs(location) - i)
        }
      }
    }

    /// 在該軌格的指定位置減少一個幅位。
    /// - Parameters:
    ///   - location: 位置。
    public func shrinkGridByOneAt(location: Int) {
      if location >= mutSpans.count {
        return
      }

      mutSpans.remove(at: location)
      for i in 0..<location {
        // zaps overlapping spans
        mutSpans[i].removeNodeOfLengthGreaterThan(location - i)
      }
    }

    /// 給定位置，枚舉出所有在這個位置結尾的節點。
    /// - Parameters:
    ///   - location: 位置。
    public func nodesEndingAt(location: Int) -> [NodeAnchor] {
      var results: [NodeAnchor] = []
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
      var results: [NodeAnchor] = []
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
    /// - Parameters:
    ///   - location: 位置。
    ///   - value: 給定字串。
    @discardableResult public func fixNodeSelectedCandidate(location: Int, value: String) -> NodeAnchor {
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
          let destinatedSpan = mutSpans[p + ni]
          for q in 0...(destinatedSpan.maximumLength) {
            if let dn = destinatedSpan.node(length: q) {
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
