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
  /// 組字器。
  public class Compositor {
    /// 給被丟掉的節點路徑施加的負權重。
    private let kDroppedPathScore: Double = -999
    /// 該組字器的游標位置。
    private var mutCursorIndex: Int = 0
    /// 該組字器的讀音陣列。
    private var mutReadings: [String] = []
    /// 該組字器的軌格。
    private var mutGrid: Grid = .init()
    /// 該組字器所使用的語言模型。
    private var mutLM: LanguageModel

    /// 公開該組字器內可以允許的最大詞長。
    public var maxBuildSpanLength: Int { mutGrid.maxBuildSpanLength }
    /// 公開：多字讀音鍵當中用以分割漢字讀音的記號，預設為空。
    public var joinSeparator: String = ""
    /// 公開：該組字器的游標位置。
    public var cursorIndex: Int {
      get { mutCursorIndex }
      set { mutCursorIndex = (newValue < 0) ? 0 : min(newValue, mutReadings.count) }
    }

    /// 公開：該組字器是否為空。
    public var isEmpty: Bool { grid.isEmpty }

    /// 公開：該組字器的軌格（唯讀）。
    public var grid: Grid { mutGrid }
    /// 公開：該組字器的長度，也就是內建漢字讀音的數量（唯讀）。
    public var length: Int { mutReadings.count }
    /// 公開：該組字器的讀音陣列（唯讀）。
    public var readings: [String] { mutReadings }

    /// 組字器。
    /// - Parameters:
    ///   - lm: 語言模型。可以是任何基於 Megrez.LanguageModel 的衍生型別。
    ///   - length: 指定該組字器內可以允許的最大詞長，預設為 10 字。
    ///   - separator: 多字讀音鍵當中用以分割漢字讀音的記號，預設為空。
    public init(lm: LanguageModel, length: Int = 10, separator: String = "") {
      mutLM = lm
      mutGrid = .init(spanLength: abs(length))  // 防呆
      joinSeparator = separator
    }

    /// 組字器自我清空專用函式。
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

    /// 移除該組字器的第一個讀音單元。
    ///
    /// 用於輸入法組字區長度上限處理：
    /// 將該位置要溢出的敲字內容遞交之後、再執行這個函式。
    @discardableResult public func removeHeadReadings(count: Int) -> Bool {
      let count = abs(count)  // 防呆
      if count > length {
        return false
      }

      for _ in 0..<count {
        if mutCursorIndex > 0 {
          mutCursorIndex -= 1
        }
        if !mutReadings.isEmpty {
          mutReadings.removeFirst()
          mutGrid.shrinkGridByOneAt(location: 0)
        }
        build()
      }

      return true
    }

    // MARK: - Walker

    /// 對已給定的軌格按照給定的位置與條件進行正向爬軌。
    /// - Parameters:
    ///   - at: 開始爬軌的位置。
    ///   - score: 給定累計權重，非必填參數。預設值為 0。
    ///   - joinedPhrase: 用以統計累計長詞的內部參數，請勿主動使用。
    ///   - longPhrases: 用以統計累計長詞的內部參數，請勿主動使用。
    public func walk(
      at location: Int = 0,
      score accumulatedScore: Double = 0.0,
      joinedPhrase: String = "",
      longPhrases: [String] = .init()
    ) -> [NodeAnchor] {
      let newLocation = (mutGrid.width) - abs(location)  // 防呆
      return Array(
        reverseWalk(
          at: newLocation, score: accumulatedScore,
          joinedPhrase: joinedPhrase, longPhrases: longPhrases
        ).reversed())
    }

    /// 對已給定的軌格按照給定的位置與條件進行反向爬軌。
    /// - Parameters:
    ///   - at: 開始爬軌的位置。
    ///   - score: 給定累計權重，非必填參數。預設值為 0。
    ///   - joinedPhrase: 用以統計累計長詞的內部參數，請勿主動使用。
    ///   - longPhrases: 用以統計累計長詞的內部參數，請勿主動使用。
    public func reverseWalk(
      at location: Int,
      score accumulatedScore: Double = 0.0,
      joinedPhrase: String = "",
      longPhrases: [String] = .init()
    ) -> [NodeAnchor] {
      let location = abs(location)  // 防呆
      if location == 0 || location > mutGrid.width {
        return .init()
      }

      var paths = [[NodeAnchor]]()
      var nodes = mutGrid.nodesEndingAt(location: location)

      nodes = nodes.stableSorted {
        $0.scoreForSort > $1.scoreForSort
      }

      if let nodeZero = nodes[0].node, nodeZero.score >= nodeZero.kSelectedCandidateScore {
        // 在使用者有選過候選字詞的情況下，摒棄非依此據而成的節點路徑。
        var anchorZero = nodes[0]
        anchorZero.accumulatedScore = accumulatedScore + nodeZero.score
        var path: [NodeAnchor] = reverseWalk(
          at: location - anchorZero.spanningLength, score: anchorZero.accumulatedScore
        )
        path.insert(anchorZero, at: 0)
        paths.append(path)
      } else if !longPhrases.isEmpty {
        var path = [NodeAnchor]()
        for theAnchor in nodes {
          guard let theNode = theAnchor.node else { continue }
          var theAnchor = theAnchor
          let joinedValue = theNode.currentKeyValue.value + joinedPhrase
          // 如果只是一堆單漢字的節點組成了同樣的長詞的話，直接棄用這個節點路徑。
          // 打比方說「八/月/中/秋/山/林/涼」與「八月/中秋/山林/涼」在使用者來看
          // 是「結果等價」的，那就扔掉前者。
          if longPhrases.contains(joinedValue) {
            theAnchor.accumulatedScore = kDroppedPathScore
            path.insert(theAnchor, at: 0)
            paths.append(path)
            continue
          }
          theAnchor.accumulatedScore = accumulatedScore + theNode.score
          path = reverseWalk(
            at: location - theAnchor.spanningLength,
            score: theAnchor.accumulatedScore,
            joinedPhrase: (joinedValue.count >= longPhrases[0].count) ? "" : joinedValue,
            longPhrases: .init()
          )
          path.insert(theAnchor, at: 0)
          paths.append(path)
        }
      } else {
        // 看看當前格位有沒有更長的候選字詞。
        var longPhrases = [String]()
        for theAnchor in nodes {
          guard let theNode = theAnchor.node else { continue }
          if theAnchor.spanningLength > 1 {
            longPhrases.append(theNode.currentKeyValue.value)
          }
        }

        longPhrases = longPhrases.stableSorted {
          $0.count > $1.count
        }
        for theAnchor in nodes {
          var theAnchor = theAnchor
          guard let theNode = theAnchor.node else { continue }
          theAnchor.accumulatedScore = accumulatedScore + theNode.score
          var path = [NodeAnchor]()
          path = reverseWalk(
            at: location - theAnchor.spanningLength, score: theAnchor.accumulatedScore,
            joinedPhrase: (theAnchor.spanningLength > 1) ? "" : theNode.currentKeyValue.value,
            longPhrases: .init()
          )
          path.insert(theAnchor, at: 0)
          paths.append(path)
        }
      }

      guard !paths.isEmpty else {
        return .init()
      }

      var result: [NodeAnchor] = paths[0]
      for neta in paths {
        if neta.last!.accumulatedScore > result.last!.accumulatedScore {
          result = neta
        }
      }

      return result
    }

    // MARK: - Private functions

    private func build() {
      let itrBegin: Int =
        (mutCursorIndex < maxBuildSpanLength) ? 0 : mutCursorIndex - maxBuildSpanLength
      let itrEnd: Int = min(mutCursorIndex + maxBuildSpanLength, mutReadings.count)

      for p in itrBegin..<itrEnd {
        for q in 1..<maxBuildSpanLength {
          if p + q > itrEnd {
            break
          }
          let arrSlice = mutReadings[p..<(p + q)]
          let combinedReading: String = join(slice: arrSlice, separator: joinSeparator)

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

    private func join(slice arrSlice: ArraySlice<String>, separator: String) -> String {
      var arrResult: [String] = []
      for value in arrSlice {
        arrResult.append(value)
      }
      return arrResult.joined(separator: separator)
    }
  }
}

// MARK: - Stable Sort Extension

// Reference: https://stackoverflow.com/a/50545761/4162914

extension Sequence {
  /// Return a stable-sorted collection.
  ///
  /// - Parameter areInIncreasingOrder: Return nil when two element are equal.
  /// - Returns: The sorted collection.
  func stableSorted(
    by areInIncreasingOrder: (Element, Element) throws -> Bool
  )
    rethrows -> [Element]
  {
    try enumerated()
      .sorted { a, b -> Bool in
        try areInIncreasingOrder(a.element, b.element)
          || (a.offset < b.offset && !areInIncreasingOrder(b.element, a.element))
      }
      .map(\.element)
  }
}
