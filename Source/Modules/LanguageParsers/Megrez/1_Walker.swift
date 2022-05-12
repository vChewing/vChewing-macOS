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
  public class Walker {
    var mutGrid: Grid

    public init(grid: Megrez.Grid = Megrez.Grid()) {
      mutGrid = grid
    }

    public func reverseWalk(
      at location: Int,
      score accumulatedScore: Double = 0.0,
      nodesLimit: Int = 0,
      balanced: Bool = false
    ) -> [NodeAnchor] {
      if location == 0 || location > mutGrid.width() {
        return [] as [NodeAnchor]
      }

      var paths: [[NodeAnchor]] = []
      var nodes: [NodeAnchor] = mutGrid.nodesEndingAt(location: location)

      if balanced {
        nodes.sort {
          $0.balancedScore > $1.balancedScore  // 排序規則已經在 NodeAnchor 內定義了。
        }
      }

      for (i, n) in nodes.enumerated() {
        // 只檢查前 X 個 NodeAnchor 是否有 node。
        // 這裡有 abs 是為了防止有白癡填負數。
        if abs(nodesLimit) > 0, i == abs(nodesLimit) - 1 {
          break
        }

        var n = n
        guard let nNode = n.node else {
          continue
        }

        n.accumulatedScore = accumulatedScore + nNode.score()

        // 利用 Spanning Length 來決定權重。
        // 這樣一來，例：「再見」比「在」與「見」的權重更高。
        if balanced {
          let weightedScore: Double = (Double(n.spanningLength) - 1) * 2
          n.accumulatedScore += weightedScore
        }

        var path: [NodeAnchor] = reverseWalk(
          at: location - n.spanningLength,
          score: n.accumulatedScore
        )

        path.insert(n, at: 0)

        paths.append(path)

        // 始終使用固定的候選字
        if balanced, nNode.score() >= 0 {
          break
        }
      }

      if !paths.isEmpty {
        if var result = paths.first {
          for value in paths {
            if let vLast = value.last, let rLast = result.last {
              if vLast.accumulatedScore > rLast.accumulatedScore {
                result = value
              }
            }
          }
          return result
        }
      }
      return [] as [NodeAnchor]
    }
  }
}
