// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

extension Homa.Assembler {
  /// 組句函式，會以 DAG (Directed Acyclic Graph) 動態規劃演算法更新當前組字器的 assembledSentence。
  ///
  /// 此演算法使用動態規劃在有向無環圖中尋找具有最優評分的路徑，從而確定最合適的詞彙組合。
  /// DAG 演算法相對於 Dijkstra 演算法更簡潔，記憶體使用量更少。
  ///
  /// - Returns: 組句結果（已選字詞陣列）。
  @discardableResult
  public func assemble() -> [Homa.GramInPath] {
    var finalScore = Double(Int32.min)
    let result = Homa.PathFinder.run(config: &config, finalScore: &finalScore)
    mostRecentPathScore = finalScore
    assembledSentence = result
    return assembledSentence
  }
}

// MARK: - Homa.PathFinder

extension Homa {
  /// 動態規劃求最佳路徑。與 `Yukuaki.PathFinder` 邏輯相同（兩個引擎的組句結果必須一致）。
  ///
  /// 這裡的狀態不是單純的「位置」，而是「位置＋前文」：到達某一格時，除了「走到哪裡」
  /// 之外還得記住「前面兩個詞分別是什麼」，因為同一個節點在不同前文下的分數不同
  /// （n-gram 加成只在命中前文時才生效）。
  ///
  /// 若只用「位置」當狀態（P324 之前的做法），就會在「左文脈還不足以定案」的格子提早
  /// 丟掉之後可能翻盤的候選：例如「要 ㄗㄞˋ ㄓㄜˋㄧㄤˋ」在走到「再」時只看得到
  /// 「要」，「再這樣」的加成要等到「這樣」被加入時才知道，於是「在」那條路早已被砍，
  /// 右文脈的 n-gram 永遠沒有機會生效。把「前文」納入狀態之後，「在」與「再」兩條
  /// 假設都會活到「這樣」被評分的那一刻，再一起比較。
  enum PathFinder {
    // MARK: Internal

    /// 一筆 DP 狀態：到達 `position` 時，前兩詞分別是 `previous` 與 `anterior`。
    struct State {
      let position: Int
      let previous: String?
      let anterior: String?
      let score: Double
      let parentID: Int
      let gram: Homa.Gram?
      let isExplicit: Bool
      let segLength: Int
    }

    /// DP 狀態鍵當中的前文部分。
    struct Ctxt: Hashable {
      let previous: String?
      let anterior: String?
    }

    /// 組句工具，會以 DAG 動態規劃演算法更新當前組字器的 assembledSentence。
    ///
    /// 該演算法使用動態規劃在有向無環圖中尋找具有最高分數的路徑，即最可能的字詞組合。
    /// - Parameters:
    ///   - config: 組字器組態。此函式只會在回溯出勝出路徑之後，把路徑上各節點的
    ///     當前元圖同步成該路徑的選擇；推導期間不動任何節點狀態。
    ///   - finalScore: 寫出本次 DP 的整句最佳路徑總分（不可達時為 `Double(Int32.min)`）。
    /// - Returns: 組句結果（已選字詞陣列）。
    @discardableResult
    static func run(config: inout Homa.Config, finalScore: inout Double) -> [Homa.GramInPath] {
      var newAssembledSentence = [Homa.GramInPath]()
      guard !config.segments.isEmpty else {
        finalScore = Double(Int32.min)
        return newAssembledSentence
      }

      let keyCount = config.keys.count

      // 只有出現在某條 gram 的前驗／前前驗欄位當中的詞值，才可能影響之後的估值。
      // 其餘詞值即使被記進狀態，也永遠命不中任何 n-gram，對未來等價於「沒有前文」，
      // 故一律收斂成 nil。這讓「沒有 n-gram 資料」的普通句子永遠只有一個狀態
      // （與 P324 之前的 1D DP 完全等價、不多花任何成本），真的有 n-gram 資料時
      // 才會分裂成多條假設。
      let relevantValues = Self.contextValues(in: config.segments)
      func canonicalized(_ value: String?) -> String? {
        guard let value, !value.isEmpty, relevantValues.contains(value) else { return nil }
        return value
      }

      var states = [State]()
      var layers = [[Int]](repeating: [], count: keyCount + 1)
      var layerLookup = [[Ctxt: Int]](repeating: [:], count: keyCount + 1)

      states.append(
        .init(
          position: 0,
          previous: nil,
          anterior: nil,
          score: 0,
          parentID: -1,
          gram: nil,
          isExplicit: false,
          segLength: 0
        )
      )
      layers[0].append(0)
      layerLookup[0][Ctxt(previous: nil, anterior: nil)] = 0

      for currentStart in 0 ..< keyCount {
        guard !layers[currentStart].isEmpty else { continue }
        let segment = config.segments[currentStart]
        guard !segment.isEmpty else { continue }
        // 段字典的迭代序不穩定；排序後再走，否則同分時的結果不可重現。
        let lengths = segment.keys.sorted()
        for stateID in layers[currentStart] {
          let state = states[stateID]
          for segLength in lengths {
            let nextStart = currentStart + segLength
            guard segLength > 0, nextStart <= keyCount, let node = segment[segLength] else { continue }
            for candidate in Self.candidates(
              of: node,
              previous: state.previous,
              anterior: state.anterior,
              relevantValues: relevantValues
            ) {
              let candidateScore = state.score + candidate.score
              // 新狀態的前文＝「剛選中的詞」與「原狀態的前驗詞」；兩者都得過同一道
              // 正規化，否則狀態鍵會被無關詞值撐爆。
              let ctxt = Ctxt(
                previous: canonicalized(candidate.gram.current),
                anterior: canonicalized(state.previous)
              )
              let next = State(
                position: currentStart,
                previous: ctxt.previous,
                anterior: ctxt.anterior,
                score: candidateScore,
                parentID: stateID,
                gram: candidate.gram,
                isExplicit: node.isExplicitlyOverridden,
                segLength: segLength
              )
              if let existingID = layerLookup[nextStart][ctxt] {
                // 同一狀態只保留分數最高者；同分時首見者勝，與既有行為一致。
                guard candidateScore > states[existingID].score else { continue }
                states[existingID] = next
              } else {
                layerLookup[nextStart][ctxt] = states.count
                layers[nextStart].append(states.count)
                states.append(next)
              }
            }
          }
        }
      }

      // 終點的狀態可能不只一個（尾端還有沒被用掉的前文），取分數最高者；同分首見者勝。
      guard var bestID = layers[keyCount].first else {
        finalScore = Double(Int32.min)
        return newAssembledSentence
      }
      for stateID in layers[keyCount] where states[stateID].score > states[bestID].score {
        bestID = stateID
      }

      var resultReversed = [Homa.GramInPath]()
      var cursor = bestID
      while cursor >= 0 {
        let state = states[cursor]
        if let gram = state.gram {
          resultReversed.append(.init(gram: gram, isExplicit: state.isExplicit))
          // 只在已經確定的勝出路徑上寫回節點狀態。推導期間不去動節點，
          // 否則同一節點會被「最後一次估值」污染，多假設之間的比較就不再可信。
          config.segments[state.position][state.segLength]?.adopt(gram: gram)
        }
        cursor = state.parentID
      }

      finalScore = states[bestID].score
      if !resultReversed.isEmpty {
        newAssembledSentence = resultReversed.reversed()
      }
      return newAssembledSentence
    }

    /// 收集節點格裡所有被當作前驗詞／前前驗詞使用過的詞值。
    static func contextValues(in segments: [Homa.Segment]) -> Set<String> {
      var result = Set<String>()
      for segment in segments {
        for node in segment.values {
          for gram in node.grams {
            if let previous = gram.previous, !previous.isEmpty { result.insert(previous) }
            if let anterior = gram.anterior, !anterior.isEmpty { result.insert(anterior) }
          }
        }
      }
      return result
    }

    /// 枚舉一個節點在此前文下「所有值得繼續走下去的候選元圖」。
    ///
    /// 只把「前文」塞進 DP 狀態還不夠：同一個節點（同一組讀音）底下掛著多個同音詞時，
    /// 若還是讓節點自己「挑一個最好的元圖」，那麼「在」與「再」在節點內部就已經分出
    /// 勝負了，右文脈的加成永遠沒有機會表態。故這裡把「節點挑一個」改成
    /// 「節點列出候選」，由 DP 帶著每條假設往前走。
    ///
    /// 候選的取捨（皆為精確規則，不是 beam）：
    /// - 每個「會被之後的 n-gram 引用到的詞值」各留一條假設（同詞值取機率最高的那條）。
    /// - 其餘單元圖對未來而言彼此等價（都不會命中任何 n-gram），只留機率最高者。
    /// - 命中前文的雙元／三元圖只要分數高過該節點的單元圖基底，就是候選
    ///   （沿用 P324 既有的「加成須高於基底」門檻，避免低分的 junk n-gram 反客為主）。
    /// - 整個節點連一條單元圖都沒有時，退回排序後的第一條元圖，與
    ///   `Homa.Node.evaluate` 的無前文分支一致。
    static func candidates(
      of node: Homa.Node,
      previous: String?,
      anterior: String?,
      relevantValues: Set<String>
    )
      -> [(gram: Homa.Gram, score: Double)] {
      guard !node.grams.isEmpty else { return [] }
      switch node.currentOverrideType {
      case .withSpecified:
        guard let gram = node.currentGram else { return [] }
        return [(gram, node.overridingScore)]
      case .withTopGramScore:
        let gram = node.currentGram ?? node.grams[0]
        return [(gram, Self.unigramBaseline(of: node) ?? gram.probability)]
      case nil:
        break
      }

      let baseline = Self.unigramBaseline(of: node) ?? -.infinity
      var result = [(gram: Homa.Gram, score: Double)]()
      var bestIrrelevantUnigram: (gram: Homa.Gram, score: Double)?
      var bestRelevantUnigrams = [String: (gram: Homa.Gram, score: Double)]()
      var hasUnigram = false
      for gram in node.grams {
        guard gram.isUnigram else {
          guard let previous, !previous.isEmpty, gram.previous == previous else { continue }
          guard gram.anterior == nil || gram.anterior == anterior else { continue }
          guard gram.probability > baseline else { continue }
          result.append((gram, gram.probability))
          continue
        }
        hasUnigram = true
        if relevantValues.contains(gram.current) {
          if let existing = bestRelevantUnigrams[gram.current], existing.score >= gram.probability { continue }
          bestRelevantUnigrams[gram.current] = (gram, gram.probability)
        } else if gram.probability > (bestIrrelevantUnigram?.score ?? -.infinity) {
          bestIrrelevantUnigram = (gram, gram.probability)
        }
      }
      result.append(contentsOf: bestRelevantUnigrams.values.sorted { $0.gram.current < $1.gram.current })
      if let bestIrrelevantUnigram { result.append(bestIrrelevantUnigram) }
      // 一條單元圖都沒有的節點：退回陣列順序上的第一條元圖，與 `Node.evaluate` 一致。
      guard hasUnigram || !result.isEmpty else { return [(node.grams[0], node.grams[0].probability)] }
      return result
    }

    // MARK: Private

    /// 陣列順序上的第一條單元圖之機率（與 `Homa.Node.evaluate` 的無前述內容分支同一定義）。
    private static func unigramBaseline(of node: Homa.Node) -> Double? {
      for gram in node.grams where gram.isUnigram {
        return gram.probability
      }
      return nil
    }
  }
}
