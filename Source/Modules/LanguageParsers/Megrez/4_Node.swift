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
  public class Node: CustomStringConvertible {
    /// 當前節點對應的語言模型。
    private let mutLM: LanguageModel = .init()
    /// 鍵。
    private var mutKey: String = ""
    /// 當前節點的當前被選中的候選字詞「在該節點內的」目前的權重。
    private var mutScore: Double = 0
    /// 單元圖陣列。
    private var mutUnigrams: [Unigram]
    /// 雙元圖陣列。
    private var mutBigrams: [Bigram]
    /// 候選字詞陣列，以鍵值陣列的形式存在。
    private var mutCandidates: [KeyValuePair] = []
    /// 專門「用單元圖資料值來調查索引值」的辭典。
    private var mutValueUnigramIndexMap: [String: Int] = [:]
    /// 專門「用給定鍵值來取對應的雙元圖陣列」的辭典。
    private var mutPrecedingBigramMap: [KeyValuePair: [Megrez.Bigram]] = [:]
    /// 狀態標記變數，用來記載當前節點是否處於候選字詞鎖定狀態。
    private var mutCandidateFixed: Bool = false
    /// 用來登記「當前選中的單元圖」的索引值的變數。
    private var mutSelectedUnigramIndex: Int = 0
    /// 用來登記要施加給「『被標記為選中狀態』的候選字詞」的複寫權重的數值。
    private let kSelectedCandidateScore: Double = 99
    /// 將當前節點列印成一個字串。
    public var description: String {
      "(node,key:\(mutKey),fixed:\(mutCandidateFixed ? "true" : "false"),selected:\(mutSelectedUnigramIndex),\(mutUnigrams))"
    }

    /// 公開：候選字詞陣列（唯讀），以鍵值陣列的形式存在。
    var candidates: [KeyValuePair] { mutCandidates }
    /// 公開：用來登記「當前選中的單元圖」的索引值的變數（唯讀）。
    var isCandidateFixed: Bool { mutCandidateFixed }

    /// 公開：鍵（唯讀）。
    var key: String { mutKey }
    /// 公開：當前節點的當前被選中的候選字詞「在該節點內的」目前的權重（唯讀）。
    var score: Double { mutScore }
    /// 公開：當前被選中的候選字詞的鍵值配對。
    var currentKeyValue: KeyValuePair {
      mutSelectedUnigramIndex >= mutUnigrams.count ? KeyValuePair() : mutCandidates[mutSelectedUnigramIndex]
    }

    /// 公開：給出當前單元圖陣列內最高的權重數值。
    var highestUnigramScore: Double { mutUnigrams.isEmpty ? 0.0 : mutUnigrams[0].score }

    /// 初期化一個節點。
    /// - Parameters:
    ///   - key: 索引鍵。
    ///   - unigrams: 單元圖陣列。
    ///   - bigrams: 雙元圖陣列（非必填）。
    public init(key: String, unigrams: [Megrez.Unigram], bigrams: [Megrez.Bigram] = []) {
      mutKey = key
      mutUnigrams = unigrams
      mutBigrams = bigrams

      mutUnigrams.sort {
        $0.score > $1.score
      }

      if mutUnigrams.count > 0 {
        mutScore = mutUnigrams[0].score
      }

      for (i, gram) in mutUnigrams.enumerated() {
        mutValueUnigramIndexMap[gram.keyValue.value] = i
        mutCandidates.append(gram.keyValue)
      }

      for gram in bigrams {
        mutPrecedingBigramMap[gram.precedingKeyValue]?.append(gram)
      }
    }

    /// 對擁有「給定的前述鍵值陣列」的節點提權。
    /// - Parameters:
    ///   - precedingKeyValues: 前述鍵值陣列。
    public func primeNodeWith(precedingKeyValues: [KeyValuePair]) {
      var newIndex = mutSelectedUnigramIndex
      var max = mutScore

      if !isCandidateFixed {
        for neta in precedingKeyValues {
          let bigrams = mutPrecedingBigramMap[neta] ?? []
          for bigram in bigrams {
            if bigram.score > max {
              if let valRetrieved = mutValueUnigramIndexMap[bigram.keyValue.value] {
                newIndex = valRetrieved as Int
                max = bigram.score
              }
            }
          }
        }
      }

      if mutScore != max {
        mutScore = max
      }

      if mutSelectedUnigramIndex != newIndex {
        mutSelectedUnigramIndex = newIndex
      }
    }

    /// 選中位於給定索引位置的候選字詞。
    /// - Parameters:
    ///   - index: 索引位置。
    ///   - fix: 是否將當前解點標記為「候選詞已鎖定」的狀態。
    public func selectCandidateAt(index: Int = 0, fix: Bool = false) {
      mutSelectedUnigramIndex = index >= mutUnigrams.count ? 0 : index
      mutCandidateFixed = fix
      mutScore = kSelectedCandidateScore
    }

    /// 重設該節點的候選字詞狀態。
    public func resetCandidate() {
      mutSelectedUnigramIndex = 0
      mutCandidateFixed = false
      if !mutUnigrams.isEmpty {
        mutScore = mutUnigrams[0].score
      }
    }

    /// 選中位於給定索引位置的候選字詞、且施加給定的權重。
    /// - Parameters:
    ///   - index: 索引位置。
    ///   - score: 給定權重條件。
    public func selectFloatingCandidateAt(index: Int, score: Double) {
      mutSelectedUnigramIndex = index >= mutUnigrams.count ? 0 : index
      mutCandidateFixed = false
      mutScore = score
    }

    /// 藉由給定的候選字詞字串，找出在庫的單元圖權重數值。沒有的話就找零。
    /// - Parameters:
    ///   - candidate: 給定的候選字詞字串。
    public func scoreFor(candidate: String) -> Double {
      for unigram in mutUnigrams {
        if unigram.keyValue.value == candidate {
          return unigram.score
        }
      }
      return 0.0
    }

    public static func == (lhs: Node, rhs: Node) -> Bool {
      lhs.mutUnigrams == rhs.mutUnigrams && lhs.mutCandidates == rhs.mutCandidates
        && lhs.mutValueUnigramIndexMap == rhs.mutValueUnigramIndexMap
        && lhs.mutPrecedingBigramMap == rhs.mutPrecedingBigramMap
        && lhs.mutCandidateFixed == rhs.mutCandidateFixed
        && lhs.mutSelectedUnigramIndex == rhs.mutSelectedUnigramIndex
    }
  }
}
