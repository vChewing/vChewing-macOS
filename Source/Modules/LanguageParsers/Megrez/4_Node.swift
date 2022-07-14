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
  /// 節點。
  public class Node: Equatable, Hashable {
    public static func == (lhs: Megrez.Node, rhs: Megrez.Node) -> Bool {
      lhs.key == rhs.key && lhs.score == rhs.score && lhs.unigrams == rhs.unigrams && lhs.bigrams == rhs.bigrams
        && lhs.candidates == rhs.candidates && lhs.valueUnigramIndexMap == rhs.valueUnigramIndexMap
        && lhs.precedingBigramMap == rhs.precedingBigramMap && lhs.isCandidateFixed == rhs.isCandidateFixed
        && lhs.selectedUnigramIndex == rhs.selectedUnigramIndex && lhs.spanLength == rhs.spanLength
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(key)
      hasher.combine(score)
      hasher.combine(unigrams)
      hasher.combine(bigrams)
      hasher.combine(spanLength)
      hasher.combine(candidates)
      hasher.combine(valueUnigramIndexMap)
      hasher.combine(precedingBigramMap)
      hasher.combine(isCandidateFixed)
      hasher.combine(selectedUnigramIndex)
    }

    /// 鍵。
    private(set) var key: String = ""
    /// 當前節點的當前被選中的候選字詞「在該節點內的」目前的權重。
    private(set) var score: Double = 0
    /// 單元圖陣列。
    private(set) var unigrams: [Unigram]
    /// 雙元圖陣列。
    private(set) var bigrams: [Bigram]
    /// 指定的幅位長度。
    public var spanLength: Int = 0
    /// 候選字詞陣列，以鍵值陣列的形式存在。
    private(set) var candidates: [KeyValuePaired] = []
    /// 專門「用單元圖資料值來調查索引值」的辭典。
    private var valueUnigramIndexMap: [String: Int] = [:]
    /// 專門「用給定鍵值來取對應的雙元圖陣列」的辭典。
    private var precedingBigramMap: [KeyValuePaired: [Megrez.Bigram]] = [:]
    /// 狀態標記變數，用來記載當前節點是否處於候選字詞鎖定狀態。
    private(set) var isCandidateFixed: Bool = false
    /// 用來登記「當前選中的單元圖」的索引值的變數。
    private var selectedUnigramIndex: Int = 0
    /// 用來登記要施加給「『被標記為選中狀態』的候選字詞」的複寫權重的數值。
    public static let kSelectedCandidateScore: Double = 99
    /// 將當前節點列印成一個字串。
    public var description: String {
      "(node,key:\(key),fixed:\(isCandidateFixed ? "true" : "false"),selected:\(selectedUnigramIndex),\(unigrams))"
    }

    /// 公開：當前被選中的候選字詞的鍵值配對。
    public var currentPair: KeyValuePaired {
      selectedUnigramIndex >= unigrams.count ? KeyValuePaired() : candidates[selectedUnigramIndex]
    }

    /// 公開：給出當前單元圖陣列內最高的權重數值。
    public var highestUnigramScore: Double { unigrams.isEmpty ? 0.0 : unigrams[0].score }

    /// 初期化一個節點。
    /// - Parameters:
    ///   - key: 索引鍵。
    ///   - unigrams: 單元圖陣列。
    ///   - bigrams: 雙元圖陣列（非必填）。
    public init(key: String = "", spanLength: Int = 0, unigrams: [Megrez.Unigram] = [], bigrams: [Megrez.Bigram] = []) {
      self.key = key
      self.unigrams = unigrams
      self.bigrams = bigrams
      self.spanLength = spanLength

      self.unigrams.sort {
        $0.score > $1.score
      }

      if !self.unigrams.isEmpty {
        score = unigrams[0].score
      }

      for (i, gram) in self.unigrams.enumerated() {
        valueUnigramIndexMap[gram.keyValue.value] = i
        candidates.append(gram.keyValue)
      }

      for gram in bigrams.lazy.filter({ [self] in
        precedingBigramMap.keys.contains($0.precedingKeyValue)
      }) {
        precedingBigramMap[gram.precedingKeyValue]?.append(gram)
      }
    }

    /// 對擁有「給定的前述鍵值陣列」的節點提權。
    /// - Parameters:
    ///   - precedingKeyValues: 前述鍵值陣列。
    public func primeNodeWith(precedingKeyValues: [KeyValuePaired]) {
      var newIndex = selectedUnigramIndex
      var max = score

      if !isCandidateFixed {
        for neta in precedingKeyValues {
          let bigrams = precedingBigramMap[neta] ?? []
          for bigram in bigrams.lazy.filter({ [self] in
            $0.score > max && valueUnigramIndexMap.keys.contains($0.keyValue.value)
          }) {
            newIndex = valueUnigramIndexMap[bigram.keyValue.value] ?? newIndex
            max = bigram.score
          }
        }
      }
      score = max
      selectedUnigramIndex = newIndex
    }

    /// 選中位於給定索引位置的候選字詞。
    /// - Parameters:
    ///   - index: 索引位置。
    ///   - fix: 是否將當前解點標記為「候選詞已鎖定」的狀態。
    public func selectCandidateAt(index: Int = 0, fix: Bool = false) {
      let index = abs(index)
      selectedUnigramIndex = index >= unigrams.count ? 0 : index
      isCandidateFixed = fix
      score = Megrez.Node.kSelectedCandidateScore
    }

    /// 重設該節點的候選字詞狀態。
    public func resetCandidate() {
      selectedUnigramIndex = 0
      isCandidateFixed = false
      if !unigrams.isEmpty {
        score = unigrams[0].score
      }
    }

    /// 選中位於給定索引位置的候選字詞、且施加給定的權重。
    /// - Parameters:
    ///   - index: 索引位置。
    ///   - score: 給定權重條件。
    public func selectFloatingCandidateAt(index: Int, score: Double) {
      let index = abs(index)  // 防呆
      selectedUnigramIndex = index >= unigrams.count ? 0 : index
      isCandidateFixed = false
      self.score = score
    }

    /// 藉由給定的候選字詞字串，找出在庫的單元圖權重數值。沒有的話就找零。
    /// - Parameters:
    ///   - candidate: 給定的候選字詞字串。
    public func scoreFor(candidate: String) -> Double {
      for unigram in unigrams.lazy.filter({ $0.keyValue.value == candidate }) {
        return unigram.score
      }
      return 0.0
    }

    /// 藉由給定的候選字詞鍵值配對，找出在庫的單元圖權重數值。沒有的話就找零。
    /// - Parameters:
    ///   - candidate: 給定的候選字詞字串。
    public func scoreForPaired(candidate: KeyValuePaired) -> Double {
      for unigram in unigrams.lazy.filter({ $0.keyValue == candidate }) {
        return unigram.score
      }
      return 0.0
    }
  }
}
