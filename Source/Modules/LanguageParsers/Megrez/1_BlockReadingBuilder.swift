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
  /// 分節讀音槽。
  public class BlockReadingBuilder {
    /// 該分節讀音曹內可以允許的最大詞長。
    private var mutMaximumBuildSpanLength = 10
    /// 該分節讀音槽的游標位置。
    private var mutCursorIndex: Int = 0
    /// 該分節讀音槽的讀音陣列。
    private var mutReadings: [String] = []
    /// 該分節讀音槽的軌格。
    private var mutGrid: Grid = .init()
    /// 該分節讀音槽所使用的語言模型。
    private var mutLM: LanguageModel

    /// 公開：多字讀音鍵當中用以分割漢字讀音的記號，預設為空。
    public var joinSeparator: String = ""
    /// 公開：該分節讀音槽的游標位置。
    public var cursorIndex: Int {
      get { mutCursorIndex }
      set { mutCursorIndex = (newValue < 0) ? 0 : min(newValue, mutReadings.count) }
    }

    /// 公開：該分節讀音槽的軌格（唯讀）。
    public var grid: Grid { mutGrid }
    /// 公開：該分節讀音槽的長度，也就是內建漢字讀音的數量（唯讀）。
    public var length: Int { mutReadings.count }
    /// 公開：該分節讀音槽的讀音陣列（唯讀）。
    public var readings: [String] { mutReadings }

    /// 分節讀音槽。
    /// - Parameters:
    ///   - lm: 語言模型。可以是任何基於 Megrez.LanguageModel 的衍生型別。
    ///   - length: 指定該分節讀音曹內可以允許的最大詞長，預設為 10 字。
    ///   - separator: 多字讀音鍵當中用以分割漢字讀音的記號，預設為空。
    public init(lm: LanguageModel, length: Int = 10, separator: String = "") {
      mutLM = lm
      mutMaximumBuildSpanLength = length
      joinSeparator = separator
    }

    /// 分節讀音槽自我清空專用函數。
    public func clear() {
      mutCursorIndex = 0
      mutReadings.removeAll()
      mutGrid.clear()
    }

    /// 在游標位置插入給定的讀音。
    /// - Parameters:
    ///   - reading: 要插入的讀音。
    public func insertReadingAtCursor(reading: String) {
      mutReadings.insert(reading, at: mutCursorIndex)
      mutGrid.expandGridByOneAt(location: mutCursorIndex)
      build()
      mutCursorIndex += 1
    }

    /// 朝著與文字輸入方向相反的方向、砍掉一個與游標相鄰的讀音。
    /// 在威注音的術語體系當中，「與文字輸入方向相反的方向」為向後（Rear）。
    @discardableResult public func deleteReadingAtTheRearOfCursor() -> Bool {
      if mutCursorIndex == 0 {
        return false
      }

      mutReadings.remove(at: mutCursorIndex - 1)
      mutCursorIndex -= 1
      mutGrid.shrinkGridByOneAt(location: mutCursorIndex)
      build()
      return true
    }

    /// 朝著往文字輸入方向、砍掉一個與游標相鄰的讀音。
    /// 在威注音的術語體系當中，「文字輸入方向」為向前（Front）。
    @discardableResult public func deleteReadingToTheFrontOfCursor() -> Bool {
      if mutCursorIndex == mutReadings.count {
        return false
      }

      mutReadings.remove(at: mutCursorIndex)
      mutGrid.shrinkGridByOneAt(location: mutCursorIndex)
      build()
      return true
    }

    /// 移除該分節讀音槽的第一個讀音單元。
    ///
    /// 用於輸入法組字區長度上限處理：
    /// 將該位置要溢出的敲字內容遞交之後、再執行這個函數。
    @discardableResult public func removeHeadReadings(count: Int) -> Bool {
      if count > length {
        return false
      }

      for _ in 0..<count {
        if mutCursorIndex > 0 {
          mutCursorIndex -= 1
        }
        mutReadings.removeFirst()
        mutGrid.shrinkGridByOneAt(location: 0)
        build()
      }

      return true
    }

    // MARK: - Walker

    /// 對已給定的軌格按照給定的位置與條件進行正向爬軌。
    ///
    /// 其實就是將反向爬軌的結果顛倒順序再給出來而已，省得使用者自己再顛倒一遍。
    /// - Parameters:
    ///   - at: 開始爬軌的位置。
    ///   - score: 給定累計權重，非必填參數。預設值為 0。
    ///   - nodesLimit: 限定最多只爬多少個節點。
    ///   - balanced: 啟用平衡權重，在節點權重的基礎上根據節點幅位長度來加權。
    public func walk(
      at location: Int,
      score accumulatedScore: Double = 0.0,
      nodesLimit: Int = 0,
      balanced: Bool = false
    ) -> [NodeAnchor] {
      Array(
        reverseWalk(
          at: location, score: accumulatedScore,
          nodesLimit: nodesLimit, balanced: balanced
        ).reversed())
    }

    /// 對已給定的軌格按照給定的位置與條件進行反向爬軌。
    /// - Parameters:
    ///   - at: 開始爬軌的位置。
    ///   - score: 給定累計權重，非必填參數。預設值為 0。
    ///   - nodesLimit: 限定最多只爬多少個節點。
    ///   - balanced: 啟用平衡權重，在節點權重的基礎上根據節點幅位長度來加權。
    public func reverseWalk(
      at location: Int,
      score accumulatedScore: Double = 0.0,
      nodesLimit: Int = 0,
      balanced: Bool = false
    ) -> [NodeAnchor] {
      if location == 0 || location > mutGrid.width {
        return [] as [NodeAnchor]
      }

      var paths: [[NodeAnchor]] = []
      var nodes: [NodeAnchor] = mutGrid.nodesEndingAt(location: location)

      if balanced {
        nodes.sort {
          $0.balancedScore > $1.balancedScore
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

        n.accumulatedScore = accumulatedScore + nNode.score

        // 利用幅位長度來決定權重。
        // 這樣一來，例：「再見」比「在」與「見」的權重更高。
        if balanced {
          n.accumulatedScore += n.additionalWeights
        }

        var path: [NodeAnchor] = reverseWalk(
          at: location - n.spanningLength,
          score: n.accumulatedScore
        )

        path.insert(n, at: 0)

        paths.append(path)

        // 始終使用固定的候選字詞
        if balanced, nNode.score >= 0 {
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

    // MARK: - Private functions

    private func build() {
      let itrBegin: Int =
        (mutCursorIndex < mutMaximumBuildSpanLength) ? 0 : mutCursorIndex - mutMaximumBuildSpanLength
      let itrEnd: Int = min(mutCursorIndex + mutMaximumBuildSpanLength, mutReadings.count)

      for p in itrBegin..<itrEnd {
        for q in 1..<mutMaximumBuildSpanLength {
          if p + q > itrEnd {
            break
          }
          let strSlice = mutReadings[p..<(p + q)]
          let combinedReading: String = join(slice: strSlice, separator: joinSeparator)

          if !mutGrid.hasMatchedNode(location: p, spanningLength: q, key: combinedReading) {
            let unigrams: [Unigram] = mutLM.unigramsFor(key: combinedReading)
            if !unigrams.isEmpty {
              let n = Node(key: combinedReading, unigrams: unigrams)
              mutGrid.insertNode(node: n, location: p, spanningLength: q)
            }
          }
        }
      }
    }

    private func join(slice strSlice: ArraySlice<String>, separator: String) -> String {
      var arrResult: [String] = []
      for value in strSlice {
        arrResult.append(value)
      }
      return arrResult.joined(separator: separator)
    }
  }
}
