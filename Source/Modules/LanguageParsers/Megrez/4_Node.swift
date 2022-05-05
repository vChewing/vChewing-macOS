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
  public class Node {
    let mutLM: LanguageModel
    var mutKey: String
    var mutScore: Double = 0
    var mutUnigrams: [Unigram]
    var mutCandidates: [KeyValuePair]
    var mutValueUnigramIndexMap: [String: Int]
    var mutPrecedingBigramMap: [KeyValuePair: [Megrez.Bigram]]

    var mutCandidateFixed: Bool = false
    var mutSelectedUnigramIndex: Int = 0

    public init(key: String, unigrams: [Megrez.Unigram], bigrams: [Megrez.Bigram] = []) {
      mutLM = LanguageModel()

      mutKey = key
      mutScore = 0

      mutUnigrams = unigrams
      mutCandidates = []
      mutValueUnigramIndexMap = [:]
      mutPrecedingBigramMap = [:]

      mutCandidateFixed = false
      mutSelectedUnigramIndex = 0

      if bigrams == [] {
        node(key: key, unigrams: unigrams, bigrams: bigrams)
      } else {
        node(key: key, unigrams: unigrams)
      }
    }

    public func node(key: String, unigrams: [Megrez.Unigram], bigrams: [Megrez.Bigram] = []) {
      var unigrams = unigrams
      mutKey = key
      unigrams.sort {
        $0.score > $1.score
      }

      if !mutUnigrams.isEmpty {
        mutScore = mutUnigrams[0].score
      }

      for (i, theGram) in unigrams.enumerated() {
        mutValueUnigramIndexMap[theGram.keyValue.value] = i
        mutCandidates.append(theGram.keyValue)
      }

      for gram in bigrams {
        mutPrecedingBigramMap[gram.precedingKeyValue]?.append(gram)
      }
    }

    public func primeNodeWith(precedingKeyValues: [KeyValuePair]) {
      var newIndex = mutSelectedUnigramIndex
      var max = mutScore

      if !isCandidateFixed() {
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

    public func isCandidateFixed() -> Bool { mutCandidateFixed }

    public func candidates() -> [KeyValuePair] { mutCandidates }

    public func selectCandidateAt(index: Int = 0, fix: Bool = false) {
      mutSelectedUnigramIndex = index >= mutUnigrams.count ? 0 : index
      mutCandidateFixed = fix
      mutScore = 99
    }

    public func resetCandidate() {
      mutSelectedUnigramIndex = 0
      mutCandidateFixed = false
      if !mutUnigrams.isEmpty {
        mutScore = mutUnigrams[0].score
      }
    }

    public func selectFloatingCandidateAt(index: Int, score: Double) {
      mutSelectedUnigramIndex = index >= mutUnigrams.count ? 0 : index
      mutCandidateFixed = false
      mutScore = score
    }

    public func key() -> String { mutKey }

    public func score() -> Double { mutScore }

    public func scoreFor(candidate: String) -> Double {
      for unigram in mutUnigrams {
        if unigram.keyValue.value == candidate {
          return unigram.score
        }
      }
      return 0.0
    }

    public func currentKeyValue() -> KeyValuePair {
      mutSelectedUnigramIndex >= mutUnigrams.count ? KeyValuePair() : mutCandidates[mutSelectedUnigramIndex]
    }

    public func highestUnigramScore() -> Double {
      mutUnigrams.isEmpty ? 0.0 : mutUnigrams[0].score
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
